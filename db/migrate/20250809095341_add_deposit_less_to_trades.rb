class AddDepositLessToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :deposit_less, :boolean, default: false, null: false
    add_index :trades, :deposit_less
  end
end
