module ActiveStorage
  class DirectUpload
    attr_reader :method, :url, :headers

    def initialize(method:, url:, headers:)
      @method = method.upcase
      @url, @headers = url, headers
    end

    def as_json(*)
      { method: method, url: url, headers: headers }
    end

  end
end
