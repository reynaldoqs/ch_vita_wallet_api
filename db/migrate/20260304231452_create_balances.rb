class CreateBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :balances do |t|
      t.references :wallet, null: false, foreign_key: true
      t.string :currency, null: false
      t.decimal :amount, precision: 18, scale: 8, default: 0, null: false

      t.timestamps
    end

    add_index :balances, %i[wallet_id currency], unique: true
  end
end
