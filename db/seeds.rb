# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

User.create!(name: "Sonia Suarez"
			 email: "sonia@cloudy.com"
			 password: "123abc"
			 password_confirmation: "123abc"
			 admin: true
			 activated: true
			 activated_at: Time.zone.now)
			 
User.create!(name: "Lena Ahiatsi"
			 email: "lena@cloudy.com"
			 password: "123abc"
			 password_confirmation: "123abc"
			 activated: true
			 activated_at: Time.zone.now)
