# frozen_string_literal: true

require "spec_helper"

feature "Darkswarm data caching", js: true, caching: true do
  let!(:taxon) { create(:taxon, name: "Cached Taxon") }
  let!(:property) { create(:property, presentation: "Cached Property") }

  let!(:producer) { create(:supplier_enterprise) }
  let!(:distributor) { create(:distributor_enterprise, with_payment_and_shipping: true, is_primary_producer: true) }
  let!(:product) { create(:simple_product, supplier: producer, primary_taxon: taxon, taxons: [taxon], properties: [property]) }
  let!(:order_cycle) { create(:simple_order_cycle, distributors: [distributor], coordinator: distributor) }
  let(:exchange) { order_cycle.exchanges.outgoing.where(receiver_id: distributor.id).first }

  before do
    exchange.variants << product.variants.first
  end

  describe "caching injected taxons and properties" do
    it "caches taxons and properties" do
      expect(Spree::Taxon).to receive(:all) { [taxon] }
      expect(Spree::Property).to receive(:all) { [property] }

      visit shops_path

      expect(Spree::Taxon).to_not receive(:all)
      expect(Spree::Property).to_not receive(:all)

      visit shops_path
    end

    xit "invalidates caches for taxons and properties" do
      visit shops_path

      taxon_timestamp1 = CacheService.latest_timestamp_by_class(Spree::Taxon)
      expect_cached "views/#{CacheService::FragmentCaching.ams_all_taxons_key}"

      property_timestamp1 = CacheService.latest_timestamp_by_class(Spree::Property)
      expect_cached "views/#{CacheService::FragmentCaching.ams_all_properties_key}"

      toggle_filters

      within "#hubs .filter-row" do
        expect(page).to have_content taxon.name
        expect(page).to have_content property.presentation
      end

      taxon.update_attributes!(name: "Changed Taxon")
      property.update_attributes!(presentation: "Changed Property")

      # Clear timed shops cache so we can test uncached supplied properties
      clear_shops_cache

      visit shops_path

      taxon_timestamp2 = CacheService.latest_timestamp_by_class(Spree::Taxon)
      expect_cached "views/#{CacheService::FragmentCaching.ams_all_taxons_key}"

      property_timestamp2 = CacheService.latest_timestamp_by_class(Spree::Property)
      expect_cached "views/#{CacheService::FragmentCaching.ams_all_properties_key}"

      expect(taxon_timestamp1).to_not eq taxon_timestamp2
      expect(property_timestamp1).to_not eq property_timestamp2

      toggle_filters

      within "#hubs .filter-row" do
        expect(page).to have_content "Changed Taxon"
        expect(page).to have_content "Changed Property"
      end
    end
  end

  def expect_cached(key)
    expect(Rails.cache.exist?(key)).to be true
  end

  def clear_shops_cache
    cache_key = "views/#{CacheService::FragmentCaching.ams_shops[0]}"
    Rails.cache.delete cache_key
  end
end
