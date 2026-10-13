# Idempotent seeds. Production has nothing to seed; development gets an admin you can sign in as
# without Hack Club Auth via /dev/sign_in_as/admin@example.com
return unless Rails.env.development?

admin = User.find_or_initialize_by(hca_id: "dev_admin")
admin.assign_attributes(email: "admin@example.com", display_name: "Dev Admin", roles: %w[admin user], timezone: "America/New_York")
admin.save!

user = User.find_or_initialize_by(hca_id: "dev_user")
user.assign_attributes(email: "user@example.com", display_name: "Dev User", roles: %w[user])
user.save!

project = user.projects.kept.find_or_create_by!(title: "Solar-powered weather station")
if project.journals.none?
  project.update!(description: "ESP32 plus a BME280, logging to a tiny dashboard. Goal: run for a week on one charge.")
  project.journals.create!(user: user, body: "Soldered the sensor board and got readings over I2C. Pressure looks off, need to check the datasheet.", duration_minutes: 90)
  project.journals.create!(user: user, body: "Deep sleep works. 12mA idle, which is too much; the regulator is probably the culprit.", duration_minutes: 150)
end

puts "Seeded: #{admin.display_name} (#{admin.public_id}, admin) and #{user.display_name} (#{user.public_id})"
puts "Dev sign in: http://localhost:3000/dev/sign_in_as/#{admin.email}"
