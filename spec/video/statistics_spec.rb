require 'spec_helper'

describe 'Yt::Video’s statistics methods', :server do
  subject(:video) { Yt::Video.new attrs }

  context 'given an existing video ID' do
    let(:attrs) { {id: $existing_video_id} }

    specify 'return all statistics data with one HTTP call' do
      expect(Net::HTTP).to receive(:start).once.and_call_original

      expect(video.view_count).to be > 0
      expect(video.like_count).to be > 0
      expect(video.dislike_count).to be > 0
      expect(video.comment_count).to be > 0
    end
  end
end
