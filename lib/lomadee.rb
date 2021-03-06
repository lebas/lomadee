require 'lomadee/version'
require 'nokogiri'
require 'open-uri'
require 'open_uri_redirections'
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
        begin
          @page = Nokogiri::HTML(open(buscape_url))
          list = @page.css('div.product-offers__container').css('li.product-offers__offer')
          list.each do |item|
            unless item.css('form').css('input').empty?
              info = item.css('form').css('input')[11].attr('value').split('|') if item.css('form').css('input')[11].attr('name').eql?("pli") && !item.css('form').css('input')[11].attr('value').nil?
              if info.size == 12
                prod << { 
                  :category_id =>  info[9].to_i,
                  :lomadee_id => item.attr('data-log_id'),
                  :product_id => info[10].to_i,
                  :sku => nil, 
                  :offer_name => item.css('form').css('input')[2].attr('value'),
                  :url => "http://www.buscape.com.br#{item.css('div.offer__thumbnail a').attr('href').value}",
                  :offer => true, 
                  :price =>  info[5].to_f, 
                  :seller => info[0].to_i
                }
              end
            end
          end 
        rescue OpenURI::HTTPError => error 
          puts ' ****** ERROR Lomadee GEM 2 ***** '
          puts buscape_url
          puts error.io.status
          puts ' ****************************** '
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
