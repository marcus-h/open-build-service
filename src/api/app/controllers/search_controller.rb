class SearchController < ApplicationController

  require 'xpath_engine'

  def project
    render :text => search(:project, true), :content_type => "text/xml"
  end

  def project_id
    render :text => search(:project, false), :content_type => "text/xml"
  end

  def package
    render :text => search(:package, true), :content_type => "text/xml"
  end

  def package_id
    render :text => search(:package, false), :content_type => "text/xml"
  end

  private

  def predicate_from_match_parameter(p)
    if p=~ /\[(.*)\]/
      pred = $1
    else
      pred = p
    end
    pred = "*" if pred.nil? or pred.empty?
    return pred
  end

  def search(what, render_all)
    predicate = predicate_from_match_parameter(params[:match])
    
    logger.debug "searching in #{what}s, predicate: '#{predicate}'"

    xe = XpathEngine.new
    collection = xe.find("/#{what}[#{predicate}]", params.slice(:sort_by, :order))
    output = String.new
    output << "<?xml version='1.0' encoding='UTF-8'?>\n"
    output << "<collection>\n"

    collection.uniq!
    collection.each do |item|
      str = (render_all ? item.to_axml : item.to_axml_id)
      output << str.split(/\n/).map {|l| "  "+l}.join("\n") + "\n"
    end

    output << "</collection>\n"
    return output
  end

  def __search_stream(xpath)
    defaults = {:render_all => true, :sort_by => nil, :order => :asc}
    opt = defaults.merge opt

    xe = XpathEngine.new
    collection = xe.find(xpath, opt.slice(:sort_by, :order))
    return Proc.new do |request,output|
      output.write "<?xml version='1.0' encoding='UTF-8'?>\n<collection>\n"
      collection.each do |item|
        if render_all
          str = item.to_axml
        else 
          str = item.to_axml_id
        end
        output.write str.split(/\n/).map {|l| "  "+l}.join("\n") + "\n"
      end
      output.write "</collection>\n"
    end
  end

  # specification of this function:
  # supported paramters:
  # ns: attribute namespace (required string)
  # name: attribute name  (required string)
  # project: limit search to project name (optional string)
  # package: limit search to package name (optional string)
  # ignorevalues: do not output attribute values (optional boolean)
  # withproject: output project defaults if no value set for package (optional boolean)
  #              such values also map against value paramter if given
  # value: limit search to attributes with value (optional string)
  # value_substr: limit search to attributes that match value substring (optional string)
  #
  # output: XML <attribute ns name><project name>values? packages?</project></attribute>
  #         with packages = <package name>values?</package>
  #          and values   = <values>value+</values>
  #          and value    = <value>CDATA</value>
  def find_attribute
  end

end
