require 'lomadee/version'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'net/http'
require 'json'

# http://developer.buscape.com.br/portal/lomadee/api-de-ofertas/recursos
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

    def read_buscape(buscape_url = nil)
      prod = []
      unless buscape_url.nil?
        @page = Nokogiri::HTML(open(buscape_url))
        list = @page.css('ul.offers-list__items').css('li.offers-list__item')
        list.each do |item|
          unless item.css('form').css('input').empty?
            lomadee_id = (item.css('form').css('input')[1].attr('name') == 'offer_id') ? item.css('form').css('input')[1].attr('value').to_i : nil
            offer_url = (item.css('form').css('input')[0].attr('name') == 'url') ? item.css('form').css('input')[0].attr('value') : nil
            seller_id = (item.css('form').css('input')[2].attr('name') == 'emp_id') ?  item.css('form').css('input')[2].attr('value').to_i : nil

            if (offer_url.upcase.include? "://TRACKER")
              page_mask = Nokogiri::HTML(open(offer_url)).css('link').map{|item| item.attr('href') if item.attr('rel') == "canonical"}.compact
              offer_url = page_mask[0] if page_mask.size == 1
            end
 
            prod << { 
              :category_id =>  item.css('form').css('input')[4].attr('value').split('|')[9].to_i,
              :lomadee_id => lomadee_id,
              :product_id => item.css('form').css('input')[4].attr('value').split('|')[10].to_i,
              :sku => nil, 
              :offer_name => list.css('div').css('a').css('img')[0].attr('alt'),
              :url => offer_url,
              :offer => true, 
              :price =>  item.css('form').attr('data-currentvalue').text.to_f, 
              :seller => seller_id
            }
          end
        end
      end
      prod
    end

    def get_suppliers
      prod = []
      unless @server_url.nil?
        url_page = "#{@server_url}service/sellers/lomadee/#{@api_id}/BR?sourceId=#{@source_id}&format=json"
        response = Net::HTTP.get(URI(url_page))
        @page = JSON.parse(response)
        unless @page.nil?
          if  @page["details"]["message"] == "success"
            sellers = @page["sellers"]
            sellers.each do |supplier|
               url = supplier["links"]
               @url_offerlist = ''
               url.map{|x| @url_offerlist = x["url"] if x["type"] == "link_to_offerlist" }
              prod << { 
                :id => supplier["id"], 
                :advertiser_id => supplier["advertiserId"], 
                :name => supplier["name"], 
                :thumbnail => supplier["thumbnail"], 
                :with_offerlist => supplier["withOffers"],
                :url_offerlist => @url_offerlist
              }
            end
          end
        end
      end
      prod
    end

    def get_products_with_keyword(keyword = nil)
      prod = []
      if !@server_url.nil? && keyword.ascii_only?
        url_page = "#{@server_url}service/findProductList/buscape/#{@api_id}/BR/?sourceId=#{@source_id}&keyword=#{keyword.downcase}"
        @page = Nokogiri::XML(open(url_page))
        if !@page.nil? && !@page.css("details").css("status").nil? && @page.css("details").css("status").text == "success"
          @page.css("product").each do |item|
            buscape_page = nil
            item.css("links").css("links").map{|link| buscape_page = link.css('link').attr('url').text if (link.css('link').attr("type").to_s == "product") }
            prod << { 
              :long_name => item.css("productName").text,
              :product_name => item.css("productShortName").text,
              :id => item.attr("id"), 
              :category_id => item.attr("categoryId"), 
              :price_min => item.css("priceMin").text, 
              :price_max => item.css("priceMax").text, 
              :product_page => buscape_page
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
