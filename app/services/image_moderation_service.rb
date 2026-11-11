require "open-uri"

class ImageModerationService
  # Níveis de SafeSearch que configuram rejeição automática
  REJECT_LIKELIHOODS = %i[POSSIBLE LIKELY VERY_LIKELY].freeze

  # Ponto de entrada do KYC: analisa frente, verso e selfie em uma única chamada batch.
  def self.analyze_kyc(document_front_url:, document_back_url:, selfie_url:, expected_name:)
    annotator = Google::Cloud::Vision.image_annotator

    front_content  = URI.open(document_front_url)  { |f| f.read }
    back_content   = URI.open(document_back_url)   { |f| f.read }
    selfie_content = URI.open(selfie_url)          { |f| f.read }

    vision_response = annotator.batch_annotate_images(
      requests: [
        {
          image:    { content: front_content },
          features: [{ type: :SAFE_SEARCH_DETECTION }, { type: :TEXT_DETECTION }]
        },
        {
          image:    { content: back_content },
          features: [{ type: :SAFE_SEARCH_DETECTION }, { type: :TEXT_DETECTION }]
        },
        {
          image:    { content: selfie_content },
          features: [{ type: :SAFE_SEARCH_DETECTION }, { type: :FACE_DETECTION }]
        }
      ]
    )

    front_r, back_r, selfie_r = vision_response.responses

    # --- 1. SafeSearch nas 3 imagens ---
    [
      [front_r,  "document_front"],
      [back_r,   "document_back"],
      [selfie_r, "selfie_with_document"]
    ].each do |response, source|
      safe = response.safe_search_annotation
      next unless safe && [safe.adult, safe.violence, safe.racy].any? { |l| REJECT_LIKELIHOODS.include?(l) }

      Rails.logger.info "[ImageModerationService] Conteúdo explícito em #{source}"
      return { status: :rejected, score: 0.1, details: { reason: "explicit_content", source: source } }
    end

    # --- 2. OCR: nome do usuário deve constar na frente ou no verso do documento ---
    front_text   = normalize(front_r.text_annotations.first&.description.to_s)
    back_text    = normalize(back_r.text_annotations.first&.description.to_s)
    combined_ocr = "#{front_text} #{back_text}"

    unless name_present?(combined_ocr, expected_name)
      Rails.logger.info "[ImageModerationService] Nome '#{expected_name}' não encontrado no documento."
      return {
        status:  :rejected,
        score:   0.0,
        details: { reason: "name_not_found_in_document" }
      }
    end

    # --- 3. Rosto presente na selfie ---
    if selfie_r.face_annotations.empty?
      Rails.logger.info "[ImageModerationService] Nenhum rosto detectado na selfie."
      return { status: :rejected, score: 0.0, details: { reason: "no_face_in_selfie" } }
    end

    # --- TODO: AWS Rekognition — comparação facial (Face Match) ---
    # Quando integrado, chamar aqui:
    #
    #   rekognition = Aws::Rekognition::Client.new(region: ENV['AWS_REGION'])
    #   result = rekognition.compare_faces(
    #     source_image: { bytes: front_content },   # rosto extraído da frente do documento
    #     target_image: { bytes: selfie_content },  # selfie do usuário
    #     similarity_threshold: 80.0
    #   )
    #   top_match = result.face_matches.max_by(&:similarity)
    #   if top_match.nil? || top_match.similarity < 80.0
    #     return { status: :rejected, score: 0.2, details: { reason: "face_mismatch" } }
    #   end
    # --- fim TODO ---

    Rails.logger.info "[ImageModerationService] KYC aprovado para '#{expected_name}'."
    { status: :approved, score: 0.99, details: { reason: "verified" } }

  rescue StandardError => e
    Rails.logger.error "[ImageModerationService] Erro na Google Vision API: #{e.class} — #{e.message}"
    { status: :manual_review, score: 0.0, details: { reason: "api_error", error: e.message } }
  end

  # ---- helpers privados ----

  def self.normalize(str)
    str.to_s
       .unicode_normalize(:nfd)
       .gsub(/\p{Mn}/, "")
       .downcase
  end
  private_class_method :normalize

  def self.name_present?(text, expected_name)
    return true if expected_name.blank?

    normalized = normalize(expected_name)
    first_name = normalized.split.first.to_s
    text.include?(normalized) || text.include?(first_name)
  end
  private_class_method :name_present?
end
