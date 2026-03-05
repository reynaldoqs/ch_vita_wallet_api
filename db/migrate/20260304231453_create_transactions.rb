class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :wallet, null: false, foreign_key: true
      t.string :from_currency, null: false
      t.string :to_currency, null: false
      t.decimal :from_amount, precision: 18, scale: 8, null: false
      t.decimal :to_amount, precision: 18, scale: 8, null: false
      t.decimal :exchange_rate, precision: 18, scale: 8, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :transactions, :status
  end
end
