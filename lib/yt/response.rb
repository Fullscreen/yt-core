module Yt
  # @private
  class Response
    def initialize(options, &block)
      @options = options
      @block = block
    end

    def run
      instance_exec @options, &@block
    end

  private

    def get(path, params = {})
      request :get, path: path, params: params
    end

    def post(path, params = {}, body = {})
      request :post, path: path, params: params, body: body
    end

    def delete(path, params = {})
      request :delete, path: path, params: params
    end

    def request(method, options = {})
      HTTPRequest.new(request_options options.merge method: method).run
    rescue HTTPError => error
      if unauthorized?(error) && refresh_access_token
        retry
      else
        raise
      end
    end

    def request_options(options)
      options[:error_message] = ->(body) {JSON(body)['error']['message']}
      if access_token = Yt.configuration.access_token || refresh_access_token
        options[:headers] = {'Authorization' => "Bearer #{access_token}"}
      else
        options[:params] = options[:params].merge key: Yt.configuration.api_key
      end
      options
    end

    def unauthorized?(error)
      error.response.is_a? Net::HTTPUnauthorized
    end

    def refresh_access_token
      if Yt.configuration.refresh_token
        auth = Auth.find_by refresh_token: Yt.configuration.refresh_token
        auth.access_token_was_refreshed
        Yt.configuration.access_token = auth.access_token
      end
    end

    def resources_path
      @options[:item_class].name.split('::').last.gsub(/^(\w{1})(.*)/) do
        "/#{@options.fetch(:api, 'youtube/v3')}/#{$1.downcase}#{$2}s"
      end
    end

    def where_params(options)
      ids = options[:conditions].fetch(:id, []).join ','
      default_params(options).merge id: ids
    end

    def channel_playlists_params(options)
      default_params(options).merge channel_id: options[:channel_id]
    end

    def channel_videos_params(options)
      params = {channel_id: options[:channel_id], order: :date, type: :video}
      default_params(options.merge parts: %i(id)).merge params
    end

    def playlist_items_params(options)
      default_params(options).merge playlist_id: options[:playlist_id]
    end

    def video_threads_params(options)
      default_params(options).merge video_id: options[:video_id]
    end

    def thread_comments_params(options)
      default_params(options).merge parent_id: options[:parent_id]
    end

    def resource_params(options)
      default_params(options).merge id: options[:ids].join(',')
    end

    def default_params(options)
      {}.tap do |params|
        if not options[:conditions].nil? then
          params.merge! options[:conditions]
        end
        params[:max_results] = 50
        params[:part] = options[:parts].join ','
        params[:page_token] = options[:offset]
      end
    end

    def slicing_conditions_every(size, &block)
      slices = @options[:conditions].fetch(:id, []).each_slice size
      slices.inject(nil) do |response, ids|
        slice_options = @options.merge conditions: {id: ids}
        response = combine_slices response, yield(slice_options)
      end
    end

    def combine_slices(total, partial)
      if total
        total.body['items'] += partial.body['items']
        total_results = partial.body['pageInfo']['totalResults']
        total.body['pageInfo']['totalResults'] += total_results
        total
      else
        partial
      end
    end

    # Expands the resultset into a collection of videos by fetching missing
    # parts, eventually with an additional HTTP request.
    def videos_for(items, key, options)
      items.body['items'].map{|item| item['id'] = item[key]['videoId']}

      if options[:parts] == %i(id)
        items
      else
        options[:ids] = items.body['items'].map{|item| item['id']}
        options[:offset] = nil
        get('/youtube/v3/videos', resource_params(options)).tap do |response|
          response.body['nextPageToken'] = items.body['nextPageToken']
        end
      end
    end
  end
end
