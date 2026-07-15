module GameInstructions
  class Serializer
    # +url_helpers+ is the controller (it responds to rails_blob_url); +host+
    # makes the generated URL absolute so the frontend, served from a different
    # origin, can load the PDF directly.
    def self.serialize_collection(instructions, url_helpers:, host:)
      new(url_helpers, host).serialize_collection(instructions)
    end

    def self.serialize(instruction, url_helpers:, host:)
      new(url_helpers, host).serialize(instruction)
    end

    def initialize(url_helpers, host)
      @url_helpers = url_helpers
      @host = host
    end

    def serialize_collection(instructions)
      instructions.map { |instruction| serialize(instruction) }
    end

    def serialize(instruction)
      {
        id: instruction.id,
        language: instruction.language,
        category: instruction.category,
        url: @url_helpers.rails_blob_url(instruction.document, host: @host)
      }
    end
  end
end
