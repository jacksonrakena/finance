class Transactions::BulkUpdatesController < ApplicationController
  def new
    @entry_ids = params.dig(:bulk_update, :entry_ids) || []
    @entries = Current.family.entries.where(id: @entry_ids)
  end

  # Fallback server-side bulk update (single request). Kept for simple flows.
  def create
    entries = Current.family.entries.where(id: bulk_update_params[:entry_ids])

    updated = entries.bulk_update!(bulk_update_params)

    action = params.dig(:bulk_update, :deposit_less_action).presence
    if action.present? && Trade.deposit_less_supported?
      enable = action == "enable"
      trade_entries = entries.select(&:trade?)
      trade_entries.each do |entry|
        entry.update!(entryable_attributes: { id: entry.entryable_id, deposit_less: enable })
        entry.lock_saved_attributes!
        entry.sync_account_later
      end
      updated += trade_entries.count
    end

    redirect_back_or_to transactions_path, notice: "#{updated} transactions updated"
  end

  # Progressive, per-entry updater for the drawer flow
  def update_one
    entry = Current.family.entries.find(params.require(:entry_id))

    attrs = { date: per_entry_params[:date], notes: per_entry_params[:notes] }.compact

    if entry.transaction? && transaction_entryable_params.present?
      attrs[:entryable_attributes] = transaction_entryable_params.merge(id: entry.entryable_id)
    end

    if entry.trade? && trade_entryable_params.present?
      attrs[:entryable_attributes] = trade_entryable_params.merge(id: entry.entryable_id)
    end

    entry.update!(attrs)
    entry.lock_saved_attributes!
    entry.sync_account_later

    render json: { ok: true, entry_id: entry.id }
  rescue => e
    render json: { ok: false, entry_id: entry&.id, error: e.message }, status: :unprocessable_entity
  end

  private
    def bulk_update_params
      params.require(:bulk_update)
            .permit(:date, :notes, :category_id, :merchant_id, entry_ids: [], tag_ids: [])
    end

    def per_entry_params
      params.require(:bulk_update)
            .permit(:date, :notes, :category_id, :merchant_id, :deposit_less_action, tag_ids: [])
    end

    def transaction_entryable_params
      per_entry_params.slice(:category_id, :merchant_id, :tag_ids)
    end

    def trade_entryable_params
      action = per_entry_params[:deposit_less_action]
      return {} if action.blank?

      case action
      when "enable"
        { deposit_less: true }
      when "disable"
        { deposit_less: false }
      else
        {}
      end
    end
end
