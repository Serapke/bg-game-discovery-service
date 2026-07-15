class GameInstruction < ApplicationRecord
  # User-uploaded reference PDFs for a game (rules summary, full manual, quick
  # reference), tagged by language and category. One file per game + language +
  # category — see the unique index and the uniqueness validation below.
  MAX_FILE_SIZE = 20.megabytes
  ALLOWED_CONTENT_TYPES = %w[application/pdf].freeze

  # Constrained pickers on the frontend mirror these. Kept as plain constants so
  # adding a language or category later is a one-line change here plus the
  # matching option on the client.
  LANGUAGES = %w[en lt].freeze
  CATEGORIES = %w[guide manual quick_reference].freeze

  belongs_to :board_game
  has_one_attached :document

  before_validation :normalize_document_content_type

  validates :language, inclusion: { in: LANGUAGES }
  validates :category, inclusion: { in: CATEGORIES }
  validates :category,
            uniqueness: { scope: [:board_game_id, :language],
                          message: "already has an instruction for this game and language" }

  validate :document_attached
  validate :document_present
  validate :document_content_type
  validate :document_size

  private

  # Rewrite the blob's content type to the byte-sniffed value so the stored blob
  # carries the correct MIME regardless of what the client declared.
  def normalize_document_content_type
    return unless document.attached? && document.blob.new_record?

    detected = detected_content_type
    document.blob.content_type = detected if ALLOWED_CONTENT_TYPES.include?(detected)
  end

  def document_attached
    errors.add(:document, "must be provided") unless document.attached?
  end

  # An empty upload sniffs as a non-PDF, which would otherwise produce a
  # confusing "must be a PDF" error. Catch it explicitly — this usually means
  # the browser couldn't read the file (e.g. a macOS permission/quarantine issue).
  def document_present
    return unless document.attached?

    if document.byte_size.to_i.zero?
      errors.add(:document, "is empty — the file couldn't be read (check the file isn't locked or restricted)")
    end
  end

  def document_content_type
    return unless document.attached?
    return if document.byte_size.to_i.zero? # document_present already reported this

    unless ALLOWED_CONTENT_TYPES.include?(detected_content_type)
      errors.add(:document, "must be a PDF")
    end
  end

  # Identify the type purely from the file's magic bytes. We deliberately pass
  # neither the filename nor the declared content type, so neither a misleading
  # client-declared type nor a lying one can influence the result — only the
  # actual bytes decide. Marcel returns application/octet-stream when it can't
  # identify the content, which correctly fails the allowlist.
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
    elsif document.blob.persisted?
      document.blob.open { |file| Marcel::MimeType.for(file) }
    else
      document.blob.content_type
    end
  rescue StandardError
    document.blob.content_type
  end

  def pending_upload_io
    change = attachment_changes["document"]
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

  def document_size
    return unless document.attached?

    if document.byte_size > MAX_FILE_SIZE
      errors.add(:document, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end
end
