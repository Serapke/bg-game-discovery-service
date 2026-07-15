module GamePhotos
  class Serializer
    # +url_helpers+ is the controller (it responds to rails_blob_url and
    # rails_representation_url); +host+ makes the generated URLs absolute so the
    # frontend, served from a different origin, can load them directly.
    def self.serialize_collection(photos, url_helpers:, host:)
      new(url_helpers, host).serialize_collection(photos)
    end

    def self.serialize(photo, url_helpers:, host:)
      new(url_helpers, host).serialize(photo)
    end

    def initialize(url_helpers, host)
      @url_helpers = url_helpers
      @host = host
    end

    def serialize_collection(photos)
      photos.map { |photo| serialize(photo) }
    end

    def serialize(photo)
      {
        id: photo.id,
        url: @url_helpers.rails_blob_url(photo.image, host: @host),
        thumbnail_url: @url_helpers.rails_representation_url(
          photo.image.variant(GamePhoto::THUMBNAIL_VARIANT), host: @host
        )
      }
    end
  end
end
