require 'spec_helper'
require 'date'

describe 'Yt::Channel#videos', :server do
  subject(:channel) { Yt::Channel.new attrs }

  context 'given an existing channel ID' do
    let(:attrs) { {id: $existing_channel_id} }

    it 'returns the list of *public* videos of the channel' do
      expect(channel.videos).to all( be_a Yt::Video )
    end

    it 'returns videos sorted by descending published date' do
      dates = channel.videos.map &:published_at
      expect(dates).to eq dates.sort.reverse
    end

    it 'returns videos published between 2 weeks and today' do
      publishedBefore = Date.today
      publishedAfter = Date.today - 2.weeks

      dates = channel.videos.where(publishedAfter: publishedAfter.rfc3339(), publishedBefore: publishedBefore.rfc3339()).map &:published_at
      expect(dates).to satisfy { |date| date >= publishedAfter.rfc3339() && date <= publishedBefore.rfc3339() }
    end

    it 'does not make any HTTP requests unless iterated', requests: 0 do
      channel.videos
    end

    it 'makes as many HTTP requests as the number of videos divided by 50', requests: 1 do
      channel.videos.map &:id
    end

    it 'reuses the previous HTTP response if the request is the same', requests: 1 do
      channel.videos.map &:id
      channel.videos.map &:id
    end

    it 'makes a new HTTP request if the request has changed', requests: 3 do
      channel.videos.map &:id
      channel.videos.select(:id, :snippet).map &:title
    end

    it 'allocates at most one Yt::Relation object, no matter the requests' do
      expect{channel.videos}.to change{ObjectSpace.each_object(Yt::Relation).count}
      expect{channel.videos}.not_to change{ObjectSpace.each_object(Yt::Relation).count}
    end

    it 'allocates at most 50 Yt::Video object, no matter the requests' do
      expect{channel.videos.map &:id}.to change{GC.start; ObjectSpace.each_object(Yt::Video).count}
      expect{channel.videos.map &:id}.not_to change{GC.start; ObjectSpace.each_object(Yt::Video).count}
      expect{channel.videos.select(:status).map &:privacy_status}.not_to change{GC.start; ObjectSpace.each_object(Yt::Video).count}
      expect{channel.videos.limit(4).map &:id}.not_to change{GC.start; ObjectSpace.each_object(Yt::Video).count}
    end

    it 'accepts .select to fetch multiple parts with two HTTP calls', requests: 2 do
      videos = channel.videos.select :snippet, :status, :statistics, :content_details
      expect(videos.map &:title).to be
      expect(videos.map &:privacy_status).to be
      expect(videos.map &:view_count).to be
      expect(videos.map &:duration).to be
    end

    it 'accepts .limit to only fetch some videos', requests: 2 do
      expect(channel.videos.select(:snippet).limit(3).count).to be 3
      expect(channel.videos.select(:snippet).limit(2).count).to be 2
      expect(channel.videos.select(:snippet).limit(1).count).to be 1
    end
  end

  context 'given a channel with more than 500 public videos' do
    let(:attrs) { {id: $gigantic_channel_id} }

    it 'returns at most 500 videos' do
      expect(channel.videos.count).to eq 500
    end

    it 'returns the number of items with one HTTP request', requests: 1 do
      expect(channel.videos.select(:snippet).size).to eq 500
    end
  end
end
