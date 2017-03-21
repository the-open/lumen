Lumen::App.controllers do

  before do
    site_admins_only!
  end

  get '/reports' do
    erb :'reports/index'
  end

  get '/reports/edit' do
    erb :'reports/index'
  end

  get '/reports/add' do
    erb :'reports/add'
  end

  post 'reports/format-data' do
    data = JSON.parse(params["data"])

    if data.first["value"].blank? and data.first["_id"].blank?
      status 400
      return
    end

    formatted_data = []

    data.each do |value|
      id = nil
      if value["_id"]["year"].blank? and value["_id"]["month"].blank? and value["_id"]["date"].blank?
        id = value.to_s
      else
        id = [value["_id"]["year"], value["_id"]["month"], value["_id"]["date"]]
      end

      formatted_data << [id, value["value"]]
    end

    formatted_data.to_json
  end

  post '/reports/run-query' do
    collection_name = params["collection"]
    query = JSON.parse(params["query"])

    client = Mongoid::Clients.default
    collection = client[collection_name]

    collection.aggregate(query).to_json
  end

end
