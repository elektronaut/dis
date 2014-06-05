Rails.application.routes.draw do

  mount BlobDispenser::Engine => "/blob_dispenser"
end
