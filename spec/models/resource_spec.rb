require File.dirname(__FILE__) + '/../spec_helper'

describe Resource do

  before(:all) do
    load_foundation_cache
    iucn_user = User.find_by_given_name('IUCN')
    iucn_content_partner = ContentPartner.find_by_user_id(iucn_user.id)
    @iucn_resource1 = Resource.gen(:content_partner => iucn_content_partner)
    @iucn_resource2 = Resource.gen(:content_partner => iucn_content_partner)
    content_partner = ContentPartner.gen(:user => User.gen)
    resource = Resource.gen(:content_partner => content_partner)
    @oldest_published_harvest_event = HarvestEvent.gen(:resource => resource, :published_at => 3.hours.ago)
    @latest_published_harvest_event = HarvestEvent.gen(:resource => resource, :published_at => 2.hours.ago)
    @latest_unpublished_harvest_event = HarvestEvent.gen(:resource => resource, :published_at => nil)
    @resource = Resource.find(resource.id)
  end

  it "should return the resource's oldest published harvest event" do
    @resource.oldest_published_harvest_event.should == @oldest_published_harvest_event
  end
  it "should return the resource's latest published harvest event" do
    @resource.latest_published_harvest_event.should == @latest_published_harvest_event
  end
# Intermittent error here (not sure what causes it):
#   1) Resource should return the resource's latest harvest event
#      Failure/Error: @resource.latest_harvest_event.should == @latest_unpublished_harvest_event
#        expected: #<HarvestEvent id: 4, resource_id: 5, began_at: "2013-02-21 20:56:41", completed_at: "2013-02-21 21:56:41", published_at: nil, publish: false>
#             got: #<HarvestEvent id: 3, resource_id: 5, began_at: "2013-02-21 20:56:41", completed_at: "2013-02-21 21:56:41", published_at: "2013-02-21 23:56:41", publish: false> (using ==)
#        Diff:
#        @@ -1,2 +1,2 @@
#        -#<HarvestEvent id: 4, resource_id: 5, began_at: "2013-02-21 20:56:41", completed_at: "2013-02-21 21:56:41", published_at: nil, publish: false>
#        +#<HarvestEvent id: 3, resource_id: 5, began_at: "2013-02-21 20:56:41", completed_at: "2013-02-21 21:56:41", published_at: "2013-02-21 23:56:41", publish: false>
  it "should return the resource's latest harvest event" do # NOTE - ordered by id, so...
    @resource.latest_harvest_event.should == @latest_unpublished_harvest_event
  end

  it '#iucn returns the last IUCN resource' do
    Resource.iucn.should == @iucn_resource2
  end

end
