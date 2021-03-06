require 'spec_helper'

describe 'Yt::Channel.where', :server do
  subject(:channels) { Yt::Channel.where id: channel_ids }

  context 'given multiple channel IDs' do
    let(:channel_ids) { [$existing_channel_id, $unknown_channel_id,
      $terminated_channel_id, $another_channel_id] }

    it 'returns the list of *existing* channels matching the conditions' do
      expect(channels).to be
      expect(channels).to all( be_a Yt::Channel )
      expect(channels.map &:id).to eq [$existing_channel_id, $another_channel_id]
    end

    it 'does not make any HTTP requests unless iterated', requests: 0 do
      channels
    end

    it 'makes as many HTTP requests as the number of channels divided by 50', requests: 1 do
      Yt::Channel.where(id: [$another_channel_id, $existing_channel_id]).map &:id
    end

    it 'reuses the previous HTTP response if the request is the same', requests: 1 do
      Yt::Channel.where(id: [$existing_channel_id]).map &:id
      Yt::Channel.where(id: [$existing_channel_id]).map &:id
    end

    it 'makes a new HTTP request if the request has changed', requests: 2 do
      Yt::Channel.where(id: [$unknown_channel_id]).map &:id
      Yt::Channel.where(id: [$another_channel_id]).map &:id
    end

    it 'allocates at most one Yt::Relation object, no matter the requests' do
      channels
      expect{channels}.not_to change{ObjectSpace.each_object(Yt::Relation).count}
    end

    it 'allocates at most 50 Yt::Channel object, no matter the requests' do
      GC.start
      Yt::Channel.where(id: [$existing_channel_id]).map &:id
      expect{Yt::Channel.where(id: [$another_channel_id]).map &:id}.not_to change{GC.start; ObjectSpace.each_object(Yt::Channel).count}
    end

    it 'accepts .select to fetch multiple parts with one HTTP calls', requests: 1 do
      list = channels.select :snippet, :status, :statistics, :branding_settings
      expect(list).to be
      expect(list.map &:title).to be
      expect(list.map &:privacy_status).to be
      expect(list.map &:view_count).to be
      expect(list.map &:keywords).to be
    end
  end
end
