require 'lomadee/version'
require 'nokogiri'
require 'open-uri'
require 'pry'

module Lomadee
  URL_SANDBOX = 'http://sandbox.buscape.com.br/'
  URL_PRODUCT = 'http://bws.buscape.com.br/'

  class Offers
    def initialize(api_id = nil, source_id = nil, sandbox = false)
      if !api_id.nil? || !source_id.nil?
        @api_id = api_id
        @source_id = source_id
        @server_url = sandbox ? URL_SANDBOX : URL_PRODUCT
      end
    end

    ### lomadeezar links da Americanas, submarinio ... 
    def add_link(url = nil)
      unless @api_id.nil? || @source_id.nil? || url.nil?
        url_page = "#{@server_url}service/createLinks/lomadee/#{@api_id}/BR/?sourceId=#{@source_id}&link1=#{url}"
        @page = Nokogiri::XML(open(url_page))
        return @page.css("redirectLink").children.text unless @page.nil? || @page.css("redirectLink").nil? || @page.css("redirectLink").children.nil?
      end
    end

    def get_stores
      prod = []
      unless @server_url.nil?
        url_page = "#{@server_url}service/sellers/lomadee/#{@api_id}/BR?sourceId=#{@source_id}"
        puts url_page
        @page = Nokogiri::XML(open(url_page))
        unless @page.nil?
          binding.pry
        end
      end
    end

    def get_products_with_keyword(keyword = nil)
      prod = []
      unless @server_url.nil?
        url_page = "#{@server_url}service/findProductList/lomadee/#{@api_id}/BR/?sourceId=#{@source_id}&keyword=#{keyword.downcase}"
        puts url_page
        @page = Nokogiri::XML(open(url_page))
        if !@page.nil? && !@page.css("details").css("status").nil? && @page.css("details").css("status").text == "success"
          @page.css("product").each do |item|
            prod << { 
              :product_name => item.css("productName").text,
              :id => item.attr("id"), 
              :category_id => item.attr("categoryId"), 
              :price_min => item.css("priceMin").text, 
              :price_max => item.css("priceMax").text
            }
          end
        else
          return nil
        end
      end
      prod
    end

    def get_offers(category = nil)
      prod = []
      unless @server_url.nil?
        url_page = "#{@server_url}service/findOfferList/lomadee/#{@api_id}/BR/?sourceId=#{@source_id}&CategoryId=#{category}&sort=dprice"
        @page = Nokogiri::XML(open(url_page))
        if !@page.nil? && !@page.css("details").css("status").nil? && @page.css("details").css("status").text == "success"
          @page.css("offer").each do |item|
            prod << { 
              :category_id => item.attr("categoryId"),
              :lomadee_id => item.attr("id"),
              :product_id => item.attr("productId"),
              :sku => item.css("sku").text, 
              :offer_name => item.css("offerShortName").text,
              :url =>  item.css('link').attr('url').text,
              :offer => item.css('link').attr('type').text == "offer" ? true : false, 
              :price => item.css('price').css('value').css('value').text, 
              :seller => item.css('seller').css('sellerName').text
            }
          end
        else
          return nil
        end
      end
      prod
    end

  end
end
