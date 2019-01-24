module ActiveStorage
  class DirectUpload
    attr_reader :method, :url, :headers

    def initialize(method:, url:, headers:)
      @method, @url, @headers = method, url, headers
    end

    def as_json(*)
      { method: method, url: url, headers: headers }
    end

  end
end
