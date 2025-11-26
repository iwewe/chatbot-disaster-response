import axios from 'axios';
import config from '../config/env.js';
import logger from '../utils/logger.js';

class OllamaService {
  constructor() {
    this.baseUrl = config.ollama.baseUrl;
    this.model = config.ollama.model;
    this.timeout = config.ollama.timeout;
    this.fallbackEnabled = config.ollama.fallbackEnabled;
    // Check if Ollama is intentionally disabled (for light deployment)
    this.isDisabled = this.baseUrl.includes('disabled') || this.baseUrl === '';

    if (this.isDisabled) {
      logger.warn('Ollama is DISABLED - using rule-based extraction only');
    }
  }

  /**
   * Generate response with structured output
   */
  async generate(prompt, options = {}) {
    const startTime = Date.now();

    try {
      logger.ai('Generating response', { model: this.model, promptLength: prompt.length });

      const response = await axios.post(
        `${this.baseUrl}/api/generate`,
        {
          model: this.model,
          prompt,
          stream: false,
          options: {
            temperature: options.temperature || 0.1, // Low temperature for consistency
            top_p: options.top_p || 0.9,
            ...options,
          },
        },
        {
          timeout: this.timeout,
        }
      );

      const duration = Date.now() - startTime;
      logger.ai('Response generated', { duration, model: this.model });

      return {
        success: true,
        response: response.data.response,
        duration,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      logger.error('Ollama generation failed', {
        error: error.message,
        duration,
        fallbackEnabled: this.fallbackEnabled,
      });

      if (this.fallbackEnabled) {
        logger.warn('Using fallback extraction');
        return {
          success: false,
          error: error.message,
          fallback: true,
        };
      }

      throw error;
    }
  }

  /**
   * Extract report data from natural language message
   */
  async extractReportData(message, userContext = {}) {
    // If Ollama is disabled, use rule-based directly
    if (this.isDisabled) {
      logger.info('Ollama disabled - using rule-based extraction');
      return this.fallbackExtraction(message);
    }

    const prompt = this.buildExtractionPrompt(message, userContext);

    try {
      const result = await this.generate(prompt);

      if (!result.success && result.fallback) {
        // Use rule-based fallback
        return this.fallbackExtraction(message);
      }

      // Parse JSON response
      const extracted = this.parseJsonResponse(result.response);
      return extracted;
    } catch (error) {
      logger.error('Failed to extract report data', { error: error.message });

      // Fallback to rule-based
      if (this.fallbackEnabled) {
        return this.fallbackExtraction(message);
      }

      throw error;
    }
  }

  /**
   * Build extraction prompt (optimized for Qwen/Llama)
   */
  buildExtractionPrompt(message, userContext) {
    const systemPrompt = `Kamu adalah asisten AI untuk sistem tanggap darurat bencana di Indonesia.

Tugasmu adalah mengekstrak informasi terstruktur dari laporan yang dikirim via WhatsApp.

JENIS LAPORAN:
1. KORBAN: Laporan orang meninggal, hilang, atau luka
2. KEBUTUHAN: Laporan kebutuhan bantuan (pangan, air, medis, shelter, evakuasi)

EKSTRAK INFORMASI BERIKUT:
- intent: "korban" atau "kebutuhan" atau "unknown"
- urgency: "critical", "high", "medium", atau "low"
- location: Lokasi (desa/kelurahan/alamat)
- summary: Ringkasan singkat (1-2 kalimat)

Untuk KORBAN, tambahkan:
- persons: Array of { name, status (meninggal/hilang/luka_berat/luka_sedang/luka_ringan/sakit), age?, gender?, condition? }

Untuk KEBUTUHAN, tambahkan:
- needs: Array of { category (pangan/air/medis/shelter/evakuasi/sanitasi/logistik_lain/perlindungan), description, quantity?, peopleAffected? }

- missingFields: Array of field names yang penting tapi belum ada (untuk follow-up question)

ATURAN:
- Jika tidak jelas, set intent: "unknown"
- Jika ada kata: mati, meninggal, tewas, jenazah → status: "meninggal"
- Jika ada kata: hilang, tidak ditemukan, dicari → status: "hilang"
- Jika ada kata: luka parah/berat, kritis → status: "luka_berat" dan urgency: "critical"
- Jika ada kata: darurat, segera, butuh cepat → urgency: "critical" atau "high"
- Ekstrak nama orang dengan hati-hati (jangan ekstrak nama tempat sebagai nama orang)
- Untuk kebutuhan, kategorikan dengan tepat

OUTPUT FORMAT: JSON murni, tanpa markdown atau teks lain.

CONTOH INPUT: "Ada 3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera. Yang parah ada Pak Budi umur 45 tahun"

CONTOH OUTPUT:
{
  "intent": "korban",
  "urgency": "high",
  "location": "Dusun Kali RT 02",
  "summary": "3 orang terluka di Dusun Kali RT 02, butuh evakuasi segera. Pak Budi (45 tahun) kondisi parah.",
  "persons": [
    {
      "name": "Pak Budi",
      "status": "luka_berat",
      "age": 45,
      "gender": "L",
      "condition": "kondisi parah"
    },
    {
      "name": "Korban 2 (tidak disebutkan nama)",
      "status": "luka_sedang"
    },
    {
      "name": "Korban 3 (tidak disebutkan nama)",
      "status": "luka_sedang"
    }
  ],
  "needs": [
    {
      "category": "evakuasi",
      "description": "Evakuasi darurat untuk 3 orang terluka",
      "peopleAffected": 3
    }
  ],
  "missingFields": []
}`;

    const userPrompt = `PESAN PENGGUNA:
${message}

${userContext.previousReport ? `KONTEKS: User ini sebelumnya melaporkan: ${userContext.previousReport}` : ''}

Ekstrak informasi dan berikan output dalam format JSON:`;

    return `${systemPrompt}\n\n${userPrompt}`;
  }

  /**
   * Parse JSON response (handle various formats)
   */
  parseJsonResponse(response) {
    try {
      // Remove markdown code blocks if present
      let cleaned = response.trim();
      cleaned = cleaned.replace(/```json\n?/g, '');
      cleaned = cleaned.replace(/```\n?/g, '');
      cleaned = cleaned.trim();

      const parsed = JSON.parse(cleaned);
      return {
        success: true,
        data: parsed,
      };
    } catch (error) {
      logger.error('Failed to parse JSON response', { error: error.message, response });
      return {
        success: false,
        error: 'Failed to parse AI response',
        rawResponse: response,
      };
    }
  }

  /**
   * Rule-based fallback extraction (simple keyword matching)
   */
  fallbackExtraction(message) {
    logger.warn('Using fallback extraction (rule-based)');

    const lowerMessage = message.toLowerCase();
    const result = {
      intent: 'unknown',
      urgency: 'medium',
      location: '',
      summary: message.substring(0, 200),
      persons: [],
      needs: [],
      missingFields: ['location'],
      fallback: true,
    };

    // Detect intent
    const korbanKeywords = ['mati', 'meninggal', 'tewas', 'hilang', 'luka', 'cedera', 'terluka', 'sakit', 'korban'];
    const kebutuhanKeywords = ['butuh', 'perlu', 'minta', 'bantuan', 'tolong', 'darurat'];

    const hasKorban = korbanKeywords.some((k) => lowerMessage.includes(k));
    const hasKebutuhan = kebutuhanKeywords.some((k) => lowerMessage.includes(k));

    if (hasKorban) {
      result.intent = 'korban';
    } else if (hasKebutuhan) {
      result.intent = 'kebutuhan';
    }

    // Detect urgency
    const urgentKeywords = ['darurat', 'segera', 'cepat', 'kritis', 'parah', 'bahaya'];
    if (urgentKeywords.some((k) => lowerMessage.includes(k))) {
      result.urgency = 'high';
    }

    // Detect critical (life-threatening)
    const criticalKeywords = ['mati', 'meninggal', 'tewas', 'kritis', 'parah sekali', 'sekarat'];
    if (criticalKeywords.some((k) => lowerMessage.includes(k))) {
      result.urgency = 'critical';
    }

    // Try to extract location (simple pattern: "di [location]")
    const locationMatch = message.match(/di\s+([A-Z][a-zA-Z\s]+(?:RT|RW)?[\s\d\/]*)/);
    if (locationMatch) {
      result.location = locationMatch[1].trim();
      result.missingFields = result.missingFields.filter((f) => f !== 'location');
    }

    // Extract numbers (potential person count)
    const numberMatch = message.match(/(\d+)\s*(orang|korban|jiwa)/);
    if (numberMatch && result.intent === 'korban') {
      const count = parseInt(numberMatch[1]);
      for (let i = 0; i < count; i++) {
        result.persons.push({
          name: `Korban ${i + 1} (tidak disebutkan nama)`,
          status: 'luka_sedang', // Default assumption
        });
      }
    }

    // Detect need categories
    const needMapping = {
      pangan: ['makan', 'makanan', 'beras', 'pangan', 'lapar'],
      air: ['air', 'minum'],
      medis: ['obat', 'medis', 'dokter', 'puskesmas', 'rs', 'rumah sakit'],
      shelter: ['tenda', 'tempat tinggal', 'shelter', 'terpal', 'matras'],
      evakuasi: ['evakuasi', 'dievakuasi', 'pindah', 'selamatkan'],
    };

    if (result.intent === 'kebutuhan') {
      for (const [category, keywords] of Object.entries(needMapping)) {
        if (keywords.some((k) => lowerMessage.includes(k))) {
          result.needs.push({
            category,
            description: `Kebutuhan ${category} (extracted via fallback)`,
          });
        }
      }
    }

    return {
      success: true,
      data: result,
    };
  }

  /**
   * Generate follow-up question based on missing fields
   */
  async generateFollowUpQuestion(reportData) {
    if (!reportData.missingFields || reportData.missingFields.length === 0) {
      return null;
    }

    const fieldTranslations = {
      location: 'Lokasi kejadian (desa/kelurahan/alamat lengkap)',
      name: 'Nama korban',
      age: 'Umur korban',
      quantity: 'Jumlah kebutuhan',
      peopleAffected: 'Jumlah orang yang terdampak',
    };

    const missingField = reportData.missingFields[0]; // Ask one at a time
    const question = fieldTranslations[missingField] || missingField;

    return `Terima kasih atas laporannya. Untuk melengkapi data, boleh kami tahu: ${question}?`;
  }

  /**
   * Health check
   */
  async healthCheck() {
    // If Ollama is disabled, return disabled status (not an error)
    if (this.isDisabled) {
      return {
        status: 'disabled',
        available: false,
        mode: 'rule-based',
        message: 'Ollama intentionally disabled - using rule-based extraction',
      };
    }

    try {
      const response = await axios.get(`${this.baseUrl}/api/tags`, {
        timeout: 5000,
      });

      const models = response.data.models || [];
      const isModelAvailable = models.some((m) => m.name.includes(this.model.split(':')[0]));

      return {
        status: 'healthy',
        available: true,
        model: this.model,
        modelAvailable: isModelAvailable,
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        available: false,
        error: error.message,
      };
    }
  }
}

export default new OllamaService();
