class WebhookEvent < ApplicationRecord
  validates :payload, presence: true
  validates :status, inclusion: { in: %w[pending processing processed failed] }

  scope :pending, -> { where(status: 'pending') }
  scope :failed, -> { where(status: 'failed') }
  scope :payments, -> { where(topic: 'payment') }

  def mark_as_failed!(error_message)
    update!(
      status: 'failed',
      processing_errors: error_message,
      attempts: attempts + 1
    )
  end

  def mark_as_processed!
    update!(
      status: 'processed',
      processed_at: Time.current,
      processing_errors: nil
    )
  end
end