class CreateWeeklyCalendars < ActiveRecord::Migration[8.0]
  def change
    create_table :weekly_calendars do |t|
      t.references :user, null: false, foreign_key: true
      t.date :week_start, null: false
      t.string :focus_area
      t.string :status, null: false, default: "pending"
      t.jsonb :posts, null: false, default: []
      t.text :error_message

      t.timestamps
    end
    add_index :weekly_calendars, [ :user_id, :week_start ]
  end
end
