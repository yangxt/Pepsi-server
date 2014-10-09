require './tests/common'
require './controllers/users_controller'

class UsersControllerTest < Test::Unit::TestCase
	include Rack::Test::Methods

	def app
		Sinatra::Application
	end

	def setup
		TestTools.delete_all
	end

	def teardown
	end

	def test_post_user
		request = TestTools.request
		response = TestTools.post(request, "/users/", nil)
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")
		json = json["body"]
		assert_not_nil(json["username"], "username doesn't match")
		assert_not_nil(json["password"], "password doesn't match")

		saved_users = ApplicationUser.all
		assert_equal(saved_users.length, 1, "number of users added doesn't match")
		saved_user = saved_users[0]
		assert_equal(saved_user.username, json["username"], "username doesn't match")
		assert_equal(saved_user.password, json["password"], "passwor doesn't match")
		assert_nil(saved_user.image_url, "image_url not nil")
		assert_equal(saved_user.name, "Unkown", "name not equal to unkown")
		assert_nil(saved_user.description, "description not nil")
	end

	def test_put_me_geolocation
		user = TestTools.create_user
		request = TestTools.request
		TestTools.authenticate(request, user)
		body = {
			"coordinates" => {
				"lat" => 43.344,
				"long" => 56.25 
			}
		}
		response = TestTools.put(request, '/me/geolocation/', body)
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		coordinate = Coordinate.first
		assert_equal(coordinate.application_user_id, user.id, "user doesn't match")
		assert_equal(coordinate.latitude, body["coordinates"]["lat"], "latitude doesn't match")
		assert_equal(coordinate.longitude, body["coordinates"]["long"], "longitude doesn't match")
	end

	def test_patch_me
		user = TestTools.create_user
		request = TestTools.request
		TestTools.authenticate(request, user)
		body = {
			"name" => "new_name",
			"image_url" => "new_image_url",
			"description" => "new_description"
		}
		response = TestTools.patch(request, '/me/', body)
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		saved_user = ApplicationUser.first
		assert_equal(saved_user, user, "user doesn't match")
		assert_equal(saved_user.name, body["name"], "name doesn't match")
		assert_equal(saved_user.image_url, body["image_url"], "image_url doesn't match")
		assert_equal(saved_user.description, body["description"], "description doesn't match")
	end

	def test_patch_me_only_name
		user = TestTools.create_user
		request = TestTools.request
		TestTools.authenticate(request, user)
		body = {
			"name" => "new_name"
		}
		response = TestTools.patch(request, '/me/', body)
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200)

		saved_user = ApplicationUser.first
		assert_equal(saved_user, user, "user doesn't match")
		assert_equal(saved_user.name, body["name"], "name doesn't match")
		assert_equal(saved_user.image_url, "image_url0", "image_url doesn't match")
	end

	def test_patch_me_only_image_url
		user = TestTools.create_user
		request = TestTools.request
		TestTools.authenticate(request, user)
		body = {
			"image_url" => "new_image_url"
		}
		response = TestTools.patch(request, '/me/', body)
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		saved_user = ApplicationUser.first
		assert_equal(saved_user, user, "user doesn't match")
		assert_equal(saved_user.name, "name0", "name doesn't match")
		assert_equal(saved_user.image_url, body["image_url"], "image_url doesn't match")
	end

	def test_get_me
		users = TestTools.create_x_users(10)
		posts = []
		myPosts = []
		for i in 0...users.length
			post = TestTools.create_post_with("text#{i}", "image_url#{i}", DateTime.now, users[i])
			posts << post
			TestTools.create_like_on_post_with_user(post, users[i])
			if i < 7
				TestTools.create_seen_on_post_with_user(post, users[i])
			end
		end

		me = TestTools.create_user_with("my_username", "my_password", "my_name", "my_image_url", "my_description")
		for i in 0...10
			myPosts << TestTools.create_post_with_user(me)
		end

		for i in 0...posts.length
			if i == 1 || i == 3
				TestTools.create_like_on_post_with_user(post, me)
			else
				TestTools.create_seen_on_post_with_user(post, me)
			end

		end

		request = TestTools.request
		TestTools.authenticate(request, me)

		response = TestTools.get(request, '/me/')
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		json = json["body"]
		assert_equal(json["id"], me.id, "id doesn't match")
		assert_equal(json["username"], me.username, "username doesn't match")
		assert_equal(json["name"], me.name, "name doesn't match")
		assert_equal(json["seens_count"], 8, "seens_count doesn't match")
		assert_equal(json["likes_count"], 2, "likes_count doesn't match")
		assert_equal(json["posts_count"], myPosts.length, "posts_count doesn't match")
		assert_equal(json["description"], me.description, "description doesn't match")
		assert_equal(json["image_url"], me.image_url, "image_url doesn't match")
	end

	def test_get_users
		me = TestTools.create_user_with("my_username", "my_password", "my_name", "my_image_url", "my_description")
		users = TestTools.create_x_users(Constants::USERS_MAX + 7)
		users.each_index do |i|
			if i > 3
				TestTools.create_coordinate_with_user(users[i], i + 0.1, i + 1.1)
			end
			if i < 3
				TestTools.create_friendship(me, users[i])
			end
			if i < 4
				post = TestTools.create_post_with("text#{i}", "image_url#{i}", DateTime.now, users[i])
				TestTools.create_like_on_post_with_user(post, users[i])
				TestTools.create_seen_on_post_with_user(post, users[i])
			end
		end
		users.reverse!

		request = TestTools.request
		TestTools.authenticate(request, me)
		response = TestTools.get(request, "/users/")
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		json = json["body"]
		retrieved_users = json["users"]
		assert_equal(retrieved_users.length, Constants::USERS_MAX, "number of retrieved_users doesn't match")

		retrieved_users.each_with_index do |ru, i|
			real_user = users[i]
			assert_equal(ru["id"], real_user.id, "id doesn't match")
			assert_equal(ru["name"], real_user.name, "name doesn't match")
			assert_equal(ru["image_url"], real_user.image_url, "image_url doesn't match")
			assert_equal(ru["description"], real_user.description, "description doesn't match")

			if ru["coordinate"] == "null"
				assert_nil(real_user.coordinate)
			else
				assert_equal(ru["coordinate"]["latitude"], real_user.coordinate.latitude, "latitude doesn't match")
				assert_equal(ru["coordinate"]["longitude"], real_user.coordinate.longitude, "longitude doesn't match")
			end
			is_friend = false
			is_friend = true if Friendship.where(:user1_id => me.id, :user2_id => real_user.id).length >= 1
			assert_equal(ru["friend"], is_friend, "friend doesn't match")
			assert_equal(ru["seens_count"], real_user.seens.count, "seens_count doesn't match")
			assert_equal(ru["likes_count"], real_user.likes.count, "likes_count doesn't match")
			assert_equal(ru["posts_count"], real_user.posts.count, "posts_count doesn't match")
		end
	end

	def test_get_user
		me = TestTools.create_user_with("my_username", "my_password", "my_name", "my_image_url", "my_description")
		user = TestTools.create_user
		TestTools.create_friendship(me, user)
		post1 = TestTools.create_post_with_user(user)
		post2 = TestTools.create_post_with_user(user)
		TestTools.create_like_on_post_with_user(post1, user)
		TestTools.create_seen_on_post_with_user(post2, user)
		TestTools.create_coordinate_with_user(user, 34, 23)

		request = TestTools.request
		TestTools.authenticate(request, me)
		response = TestTools.get(request, "/users/#{user.id}")
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		json = json["body"]

		assert_equal(json["id"], user.id, "id doesn't match")
		assert_equal(json["name"], user.name, "name doesn't match")
		assert_equal(json["image_url"], user.image_url, "image_url doesn't match")
		assert_equal(json["description"], user.description, "description doesn't match")
		assert_equal(json["coordinate"]["latitude"], user.coordinate.latitude, "latitude doesn't match")
		assert_equal(json["coordinate"]["longitude"], user.coordinate.longitude, "longitude doesn't match")
		assert_equal(json["friend"], true, "friend doesn't match")
		assert_equal(json["seens_count"], user.seens.count, "seens_count doesn't match")
		assert_equal(json["likes_count"], user.likes.count, "likes_count doesn't match")
		assert_equal(json["posts_count"], user.posts.count, "posts_count doesn't match")
	end

	def test_get_user_posts
		me = TestTools.create_user_with("my_username", "my_password", "my_name", "my_image_url", "my_description")
		user = TestTools.create_user
		TestTools.create_friendship(me, user)
		posts = TestTools.create_x_posts_with_user(user, Constants::POSTS_PER_PAGE + 5)
		liked = []
		seen = []

		for i in 0...posts.length
			if i < 3
				TestTools.create_x_tags_with_post(posts[i], 2)
				TestTools.create_like_on_post_with_user(posts[i], user)
				TestTools.create_comment_with_post_and_user(posts[i], user)
			end
			if i > 1
				TestTools.create_like_on_post_with_user(posts[i], me)
				liked << true
				seen << false
			else
				TestTools.create_seen_on_post_with_user(posts[i], me)
				liked << false
				seen << true
			end
		end
		posts.reverse!
		liked.reverse!
		seen.reverse!

		request = TestTools.request
		TestTools.authenticate(request, me)
		response = TestTools.get(request, "/users/#{user.id}/posts/?last_id=#{posts[Constants::POSTS_PER_PAGE - 1].id}")
		json = JSON.parse(response.body);
		assert_equal(json["status"], 200, "status code doesn't match")

		json = json["body"]

		assert_equal(json["posts_count"], Constants::POSTS_PER_PAGE + 5, "count of posts doesn't match")
		assert_equal(json["likes_count"], 3, "count of likes doesn't match")
		retrieved_posts = json["posts"]
		assert_equal(retrieved_posts.length, 5, "number of posts doesn't match")

		retrieved_posts.each_index do |i|
			retrieved_post = retrieved_posts[i]
			real_post = posts[i + Constants::POSTS_PER_PAGE]
			assert_equal(retrieved_post["id"], real_post.id, "id doesn't match")
			assert_equal(retrieved_post["text"], real_post.text, "text doesn't match")
	  		assert_equal(DateTime.parse(retrieved_post["creation_date"].to_s), real_post.creation_date.to_s, "creation_date doesn't match")
	  		assert_equal(retrieved_post["likes_count"], real_post.likes.count, "likes count doesn't match")
	  		assert_equal(retrieved_post["seens_count"], real_post.seens.count, "seens_count doesn't match")
	  		assert_equal(retrieved_post["comments_count"], real_post.comments.count, "comments_count doesn't match")
	  		assert_equal(retrieved_post["seen"], seen[i + Constants::POSTS_PER_PAGE], "seen doesn't match")
	  		assert_equal(retrieved_post["liked"], liked[i + Constants::POSTS_PER_PAGE], "liked doesn't match")
	  		assert_equal(retrieved_post["owner"]["name"], user.name, "liked doesn't match")
	  		assert_equal(retrieved_post["owner"]["image_url"], user.image_url, "liked doesn't match")
	  		assert_equal(retrieved_post["owner"]["friend"], true, "liked doesn't match")
	  		
	  		retrieved_tags = retrieved_post["tags"]
	  		if retrieved_tags
	  			real_tags = []
	  			real_post.tags.each do |t|
	  				real_tags << t.text
	  			end
	  			retrieved_tags.each do |t|
	  				assert(real_tags.include?(t))
	  			end
	  		end
		end
	end

	def test_get_user_with_bounds
		me = TestTools.create_user_with("my_username", "my_password", "my_name", "my_image_url", "my_description")
		users = TestTools.create_x_users(9)
		latitude_bounds = {
			:max => 23.2,
			:min => 12.4
		}
		longitude_bounds = {
			:max => 65.2,
			:min => 24.2
		}
		users_in_bounds = []
		users.each_index do |i|
			if i < 5
				latitude = Random.rand(latitude_bounds[:min]..latitude_bounds[:max])
				longitude = Random.rand(longitude_bounds[:min]..longitude_bounds[:max])
				users_in_bounds << users[i]
			else
				latitude = Random.rand(0.0..latitude_bounds[:min])
				longitude = Random.rand(longitude_bounds[:max]..100.0)
			end
			TestTools.create_coordinate_with_user(users[i], latitude, longitude)
		end
		users_in_bounds.reverse!

		request = TestTools.request
		TestTools.authenticate(request, me)
		response = TestTools.get(request, "/users/?from_lat=#{latitude_bounds[:min]}&to_lat=#{latitude_bounds[:max]}&from_long=#{longitude_bounds[:min]}&to_long=#{longitude_bounds[:max]}")
		json = JSON.parse(response.body)
		assert_equal(json["status"], 200, "status code doesn't match")

		json = json["body"]
		retrieved_users = json["users"]
		assert_equal(users_in_bounds.length, retrieved_users.length, "not the same number of users retrieved")
		retrieved_users.each_index do |i|
			retrieved_user = retrieved_users[i]
			real_user = users_in_bounds[i]
			assert_equal(retrieved_user["id"], real_user.id)
		end
	end
end
