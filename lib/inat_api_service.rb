#encoding: utf-8
module INatAPIService

  ENDPOINT = CONFIG.node_api_url
  TIMEOUT = 8

  def self.identifications(params={})
    return INatAPIService.get("/identifications", params)
  end

  def self.identifications_categories(params={})
    return INatAPIService.get("/identifications/categories", params)
  end

  def self.observations(params={})
    return INatAPIService.get("/observations", params)
  end

  def self.observations_observers(params={})
    return INatAPIService.get("/observations/observers", params)
  end

  def self.observations_species_counts(params={})
    return INatAPIService.get("/observations/species_counts", params)
  end

  def self.observations_popular_field_values(params={})
    return INatAPIService.get("/observations/popular_field_values", params)
  end

  def self.geoip_lookup(params={})
    return INatAPIService.get("/geoip_lookup", params)
  end

  def self.get_json( path, params = {}, retries = 3, timeout = INatAPIService::TIMEOUT )
    url = INatAPIService::ENDPOINT + path;
    headers = {}
    if api_token = params.delete(:api_token)
      headers["Authorization"] = api_token
    end
    unless params.blank? || !params.is_a?(Hash)
      url += "?" + params.map{|k,v| "#{k}=#{[v].flatten.join(',')}"}.join("&")
    end
    uri = URI(url)
    begin
      timed_out = Timeout::timeout( timeout ) do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if uri.scheme == "https"
        # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        response = http.get( uri.request_uri, headers )
        if response.code == "200"
          return response.body.force_encoding( "utf-8" )
        end
      end
    rescue => e
      Rails.logger.debug "[DEBUG] INatAPIService.get_json(#{path}, #{params}, #{retries}) failed: #{e}"
    end
    if retries.is_a?(Fixnum) && retries > 0
      return INatAPIService.get_json( path, params, retries - 1 )
    end
    false
  end

  def self.get( path, params = {}, retries = 3 )
    json = get_json( path, params, retries )
    return unless json
    OpenStruct.new_recursive( JSON.parse( json ) || {} )
  end
end
