class AddPingMessageToDayEndReminders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :day_end_reminders, :ping_channel_id, :string
    add_column :day_end_reminders, :ping_ts, :string
    add_index :day_end_reminders, %i[ping_channel_id ping_ts], algorithm: :concurrently
  end
end
