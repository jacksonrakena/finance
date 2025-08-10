class Entry < ApplicationRecord
  include Monetizable, Enrichable

  monetize :amount

  belongs_to :account
  belongs_to :transfer, optional: true
  belongs_to :import, optional: true

  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
  accepts_nested_attributes_for :entryable

  validates :date, :name, :amount, :currency, presence: true
  validates :date, uniqueness: { scope: [ :account_id, :entryable_type ] }, if: -> { valuation? }
  validates :date, comparison: { greater_than: -> { min_supported_date } }

  scope :visible, -> {
    joins(:account).where(accounts: { status: [ "draft", "active" ] })
  }

  scope :chronological, -> {
    order(
      date: :asc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :asc,
      created_at: :asc
    )
  }

  scope :reverse_chronological, -> {
    order(
      date: :desc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :desc,
      created_at: :desc
    )
  }

  def classification
    amount.negative? ? "income" : "expense"
  end

  def lock_saved_attributes!
    super
    entryable.lock_saved_attributes!
  end

  def sync_account_later
    sync_start_date = [ date_previously_was, date ].compact.min unless destroyed?
    account.sync_later(window_start_date: sync_start_date)
  end

  def entryable_name_short
    entryable_type.demodulize.underscore
  end

  def balance_trend(entries, balances)
    Balance::TrendCalculator.new(self, entries, balances).trend
  end

  def linked?
    plaid_id.present?
  end

  class << self
    def search(params)
      EntrySearch.new(params).build_query(all)
    end

    # arbitrary cutoff date to avoid expensive sync operations
    def min_supported_date
      30.years.ago.to_date
    end

    def bulk_update!(bulk_update_params)
      # Determine if there is anything to update at all
      has_any_common_attrs = bulk_update_params[:date].present? || bulk_update_params[:notes].present?
      has_any_txn_attrs = bulk_update_params[:category_id].present? || bulk_update_params[:merchant_id].present? || (bulk_update_params[:tag_ids].present? && bulk_update_params[:tag_ids].any?)
      return 0 unless has_any_common_attrs || has_any_txn_attrs

      updated_count = 0

      transaction do
        all.each do |entry|
          entry_attrs = {}
          entry_attrs[:date] = bulk_update_params[:date] if bulk_update_params[:date].present?
          entry_attrs[:notes] = bulk_update_params[:notes] if bulk_update_params[:notes].present?

          if entry.transaction?
            ea = {}
            ea[:category_id] = bulk_update_params[:category_id] if bulk_update_params[:category_id].present?
            ea[:merchant_id] = bulk_update_params[:merchant_id] if bulk_update_params[:merchant_id].present?
            if bulk_update_params[:tag_ids].present? && bulk_update_params[:tag_ids].any?
              ea[:tag_ids] = bulk_update_params[:tag_ids]
            end
            entry_attrs[:entryable_attributes] = ea.merge(id: entry.entryable_id) if ea.present?
          end

          next if entry_attrs.blank?

          entry.update!(entry_attrs)
          updated_count += 1

          entry.lock_saved_attributes!
          entry.entryable.lock_attr!(:tag_ids) if entry.transaction? && entry.transaction.tags.any?
        end
      end

      updated_count
    end
  end
end
