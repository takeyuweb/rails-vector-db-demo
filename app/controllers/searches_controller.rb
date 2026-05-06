class SearchesController < ApplicationController
  TOP_K = 10

  # GET /search
  # GET /search?q=...
  def show
    @query = params[:q].to_s.strip
    @results = []
    @search_failed = false

    return if @query.blank?

    begin
      query_vector, _model_identifier = Rails.application.config.embedding_model.embed_query(@query)
      @results = Rails.application.config.vector_search.search(
        query_vector: query_vector,
        k: TOP_K
      )
    rescue StandardError => e
      Rails.logger.error("Search failed: #{e.class}: #{e.message}")
      @search_failed = true
    end
  end
end
