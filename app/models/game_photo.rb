class GamePhoto < ApplicationRecord
  # User-uploaded photos for a game (box art, components, table setup) — distinct
  # from the read-only BGG image_url/thumbnail_url stored on BoardGame itself.
  MAX_PER_GAME = 20
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/avif].freeze

  # A small variant for the gallery grid so we don't ship full-resolution
  # phone photos to every thumbnail.
  THUMBNAIL_VARIANT = { resize_to_limit: [400, 400] }.freeze

  belongs_to :board_game
  has_one_attached :image

  before_validation :normalize_image_content_type
  validate :image_attached
  validate :image_present
  validate :image_content_type
  validate :image_size
  validate :photo_count_within_limit, on: :create

  private

  # Rewrite the blob's content type to the byte-sniffed value so the stored
  # blob and its served variants carry the correct MIME, regardless of what
  # the client declared.
  def normalize_image_content_type
    return unless image.attached? && image.blob.new_record?

    detected = detected_content_type
    image.blob.content_type = detected if ALLOWED_CONTENT_TYPES.include?(detected)
  end

  def image_attached
    errors.add(:image, "must be provided") unless image.attached?
  end

  # An empty upload sniffs as a non-image, which would otherwise produce a
  # confusing "must be a JPEG" error. Catch it explicitly — this usually means
  # the browser couldn't read the file (e.g. a macOS permission/quarantine issue).
  def image_present
    return unless image.attached?

    if image.byte_size.to_i.zero?
      errors.add(:image, "is empty — the file couldn't be read (check the file isn't locked or restricted)")
    end
  end

  def image_content_type
    return unless image.attached?
    return if image.byte_size.to_i.zero? # image_present already reported this

    unless ALLOWED_CONTENT_TYPES.include?(detected_content_type)
      errors.add(:image, "must be a JPEG, PNG, WebP, or AVIF image")
    end
  end

  # Identify the type purely from the file's magic bytes. We deliberately pass
  # neither the filename nor the declared content type, so neither a misleading
  # client-declared type (a real JPEG sent as application/octet-stream) nor a
  # lying one (text bytes claiming to be image/jpeg) can influence the result —
  # only the actual bytes decide. Marcel returns application/octet-stream when
  # it can't identify the content, which correctly fails the allowlist.
  #
  # At validation time the blob usually isn't uploaded to the storage service
  # yet, so read from the pending upload (the attachable) when present and fall
  # back to the stored blob otherwise.
  def detected_content_type
    @detected_content_type ||= sniff_content_type
  end

  def sniff_content_type
    io = pending_upload_io
    if io
      begin
        Marcel::MimeType.for(io)
      ensure
        io.rewind if io.respond_to?(:rewind)
      end
    elsif image.blob.persisted?
      image.blob.open { |file| Marcel::MimeType.for(file) }
    else
      image.blob.content_type
    end
  rescue StandardError
    image.blob.content_type
  end

  def pending_upload_io
    change = attachment_changes["image"]
    return unless change.respond_to?(:attachable)

    case (attachable = change.attachable)
    when ActionDispatch::Http::UploadedFile, Rack::Test::UploadedFile
      attachable.tempfile
    when Hash
      attachable[:io]
    when IO, StringIO, File, Tempfile
      attachable
    end
  end

  def image_size
    return unless image.attached?

    if image.byte_size > MAX_FILE_SIZE
      errors.add(:image, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end

  def photo_count_within_limit
    return unless board_game

    if board_game.game_photos.count >= MAX_PER_GAME
      errors.add(:base, "a game can have at most #{MAX_PER_GAME} photos")
    end
  end
end
