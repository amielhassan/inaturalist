require File.dirname(__FILE__) + '/../spec_helper'

shared_examples_for "a signed in UsersController" do
  before(:all) { User.destroy_all }
  elastic_models( Observation )
  before { enable_has_subscribers }
  after {  disable_has_subscribers }
  let(:user) { User.make! }
  it "should show email for edit" do
    get :edit, :format => :json
    expect(response).to be_success
    expect(response.body).to be =~ /#{user.email}/
  end

  it "should show the dashboard" do
    get :dashboard
    expect(response).to be_success
  end

  describe "update" do
    it "should remove the user icon with icon_delete param" do
      user.icon = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      user.save!
      expect( user.icon_file_name ).not_to be_blank
      put :update, id: user.id, format: :json, icon_delete: true
      expect( response ).to be_success
      user.reload
      expect( user.icon_file_name ).to be_blank
    end
    it "should not remove the user icon with no user[icon] param" do
      user.icon = File.open( File.join( Rails.root, "spec", "fixtures", "files", "cuthona_abronia-tagged.jpg" ) )
      user.save!
      expect( user.icon_file_name ).not_to be_blank
      new_desc = "show me the tarweeds"
      put :update, id: user.id, format: :json, user: { description: new_desc }
      expect( response ).to be_success
      user.reload
      expect( user.description ).to eq new_desc
      expect( user.icon_file_name ).not_to be_blank
    end
    describe "observation license preference" do
      it "should update past observations if requested" do
        user.update_attributes( preferred_observation_license: Observation::CC_BY )
        o = Observation.make!( user: user )
        expect( o.license ).to eq Observation::CC_BY
        put :update, id: user.id, format: :json, user: { preferred_observation_license: Observation::CC0, make_observation_licenses_same: "1" }
        o.reload
        expect( o.license ).to eq Observation::CC0
      end
      it "should update re-index past observations" do
        user.update_attributes( preferred_observation_license: Observation::CC_BY )
        o = Observation.make!( user: user )
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.license_code ).to eq Observation::CC_BY.downcase
        put :update, id: user.id, format: :json, user: {
          preferred_observation_license: "",
          make_observation_licenses_same: "1"
        }
        Delayed::Worker.new.work_off
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.license_code ).to be_blank
      end
    end
    describe "photo license preference" do
      it "should update past observations if requested" do
        user.update_attributes( preferred_photo_license: Observation::CC_BY )
        p = LocalPhoto.make!( user: user )
        expect( p.license_code ).to eq Observation::CC_BY
        put :update, id: user.id, format: :json, user: {
          preferred_photo_license: Observation::CC0,
          make_photo_licenses_same: "1"
        }
        p.reload
        expect( p.license_code ).to eq Observation::CC0
      end
      # Honestly not sure why this passes
      it "should update re-index past observations" do
        user.update_attributes( preferred_photo_license: Observation::CC_BY )
        o = make_research_grade_observation( user: user )
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.photo_licenses ).to include Observation::CC_BY.downcase
        put :update, id: user.id, format: :json, user: {
          preferred_photo_license: "",
          make_photo_licenses_same: "1"
        }
        Delayed::Worker.new.work_off
        es_response = Observation.elastic_search( where: { id: o.id } ).results.results.first
        expect( es_response.photo_licenses ).to be_blank
      end
    end

    describe "friend_id" do
      it "should create a friendship if one doesn't exist" do
        friend = User.make!
        expect( user.followees ).not_to include friend
        put :update, format: :json, id: user.id, friend_id: friend.id
        user.reload
        expect( user.followees ).to include friend
      end
      it "should update a friendship if one exists" do
        friendship = Friendship.make!( user: user, following: false, trust: true )
        expect( user.followees ).not_to include friendship.friend
        put :update, format: :json, id: user.id, friend_id: friendship.friend.id
        expect( user.followees ).to include friendship.friend
        friendship.reload
        expect( friendship ).to be_following
      end
    end

    describe "remove_friend_id" do
      it "should update a friendship if one exist" do
        friendship = Friendship.make!( user: user, following: false, trust: true )
        expect( user.followees ).not_to include friendship.friend
        put :update, format: :json, id: user.id, remove_friend_id: friendship.friend.id
        expect( user.followees ).not_to include friendship.friend
        friendship.reload
        expect( friendship ).not_to be_following
      end
    end
  end

  describe "new_updates" do
    before { CONFIG.has_subscribers = :enabled }
    after { CONFIG.has_subscribers = :disabled }
    it "should show recent updates" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json
      json = JSON.parse(response.body)
      expect(json.size).to be > 0
    end

    it "return mentions" do
      without_delay { Comment.make!(body: "hey @#{ user.login }") }
      get :new_updates, format: :json, notification: "mention"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0
      expect(json.first["notification"]).to eq "mention"
    end

    it "should filter by resource_type" do
      p = Post.make!(:parent => user, :user => user)
      without_delay { Comment.make!(:parent => p) }
      get :new_updates, :format => :json, :resource_type => "Post"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0

      get :new_updates, :format => :json, :resource_type => "Observation"
      json = JSON.parse(response.body)
      expect(json).to be_blank
      expect(json.size).to eq 0
    end

    it "should filter by notifier_type" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      get :new_updates, :format => :json, :notifier_type => "Comment"
      json = JSON.parse(response.body)
      expect(json.size).to be > 0

      get :new_updates, :format => :json, :notifier_type => "Identification"
      json = JSON.parse(response.body)
      expect(json).to be_blank
      expect(json.size).to eq 0
    end

    it "should allow user to skip marking the updates as viewed" do
      o = Observation.make!(:user => user)
      without_delay { Comment.make!(:parent => o) }
      expect( UpdateAction.unviewed_by_user_from_query(user.id, resource: o) ).to eq true
      get :new_updates, :format => :json, :skip_view => true
      Delayed::Worker.new(:quiet => true).work_off
      expect( UpdateAction.unviewed_by_user_from_query(user.id, resource: o) ).to eq true
    end
  end

  describe "search" do
    it "should search by username" do
      u = User.make!
      get :search, :q => u.login, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u.id}).not_to be_blank
    end

    it "should allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u.id}).not_to be_blank
    end
  end

  describe "test_groups" do
    it "should be set with update" do
      test_groups = "foo"
      expect( user.test_groups ).to be_blank
      put :update, id: user.id, user: { test_groups: test_groups }
      user.reload
      expect( user.test_groups ).to eq test_groups
    end
  end

end

describe UsersController, "oauth authentication" do
  let(:token) { double :acceptable? => true, :accessible? => true, :resource_owner_id => user.id }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow(controller).to receive(:doorkeeper_token) { token }
  end
  it_behaves_like "a signed in UsersController"
end

describe UsersController, "without authentication" do
  it "should not show email for edit" do
    user = User.make!
    get :edit, :format => :json, :id => user.id
    expect(response).not_to be_success
    expect(response.body).not_to be =~ /#{user.email}/
  end

  describe "show" do
    let( :user ) { User.make! }
    it "should show observations_count" do
      get :show, format: :json, id: user.id
      expect( response ).to be_success
      expect( JSON.parse( response.body )["observations_count"] ).to eq 0
    end
    it "should show identifications_count" do
      get :show, format: :json, id: user.id
      expect( response ).to be_success
      expect( JSON.parse( response.body )["identifications_count"] ).to eq 0
    end
  end

  describe "search" do
    it "should search by username" do
      u1 = User.make!(:login => "foo")
      u2 = User.make!(:login => "bar")
      get :search, :q => u1.login, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json.detect{|ju| ju['id'] == u1.id}).not_to be_blank
      expect(json.detect{|ju| ju['id'] == u2.id}).to be_blank
    end
    
    it "should not allow email searches" do
      u = User.make!
      get :search, :q => u.email, :format => :json
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json).to be_blank
    end

    it "can order by activity" do
      u1 = User.make!(login: "aaa", observations_count: 2)
      u2 = User.make!(login: "abb", observations_count: 1)
      u3 = User.make!(login: "acc", observations_count: 3)
      get :search, q: "a", format: :json
      expect(JSON.parse(response.body).map{ |r| r["login"] }).to eq [ "aaa", "abb", "acc" ]
      get :search, q: "a", format: :json, order: "activity"
      expect(JSON.parse(response.body).map{ |r| r["login"] }).to eq [ "acc", "aaa", "abb" ]
    end
  end

  describe "parental_consent" do
    it "should deliver an email with the application JWT" do
      deliveries = ActionMailer::Base.deliveries.size
      token = JsonWebToken.applicationToken
      request.env["HTTP_AUTHORIZATION"] = token
      post :parental_consent, format: :json, email: Faker::Internet.email
      expect( ActionMailer::Base.deliveries.size ).to eq deliveries + 1
    end
    it "should not deliver an email without the application JWT" do
      deliveries = ActionMailer::Base.deliveries.size
      token = JsonWebToken.applicationToken + "bad"
      request.env["HTTP_AUTHORIZATION"] = token
      post :parental_consent, format: :json, email: Faker::Internet.email
      expect( ActionMailer::Base.deliveries.size ).to eq deliveries
    end
    describe "should return a 422 with" do
      it "no email" do
        token = JsonWebToken.applicationToken
        request.env["HTTP_AUTHORIZATION"] = token
        post :parental_consent, format: :json
        expect( response.status ).to eq 422
      end
      it "a bad email" do
        token = JsonWebToken.applicationToken
        request.env["HTTP_AUTHORIZATION"] = token
        post :parental_consent, format: :json, email: "lkdshglsdhfg"
        expect( response.status ).to eq 422
      end
    end
  end

end

describe UsersController, "oauth authentication with login scope" do
  let(:user) { User.make! }
  let(:token) { Doorkeeper::AccessToken.create!(
    application: OauthApplication.make!,
    scopes: "login",
    resource_owner_id: user.id
  ) }
  before do
    request.env["HTTP_AUTHORIZATION"] = "Bearer xxx"
    allow( controller ).to receive(:doorkeeper_token) { token }
  end
  describe "edit" do
    it "should return email" do
      get :edit, format: :json
      json = JSON.parse( response.body )
      expect( json["email"] ).to eq user.email
    end
  end
  describe "update" do
    it "should not work" do
      old_name = user.name
      put :update, format: :json, id: user.id, user: { name: "#{user.name} this is a new name" }
      user.reload
      expect( user.name ).to eq old_name
    end
  end
end
