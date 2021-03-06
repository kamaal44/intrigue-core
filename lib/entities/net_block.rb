module Intrigue
module Entity
class NetBlock < Intrigue::Model::Entity

  def self.metadata
    {
      :name => "NetBlock",
      :description => "A Block of IPs",
      :user_creatable => true,
      :example => "1.1.1.1/24"
    }
  end

  def validate_entity

    # fail if they don't exist
    name =~ /^\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}\/\d{1,2}$/

    # warn if they don't exist:
    # details["organization_reference"]
    # details["whois_full_text"]
  end

  def detail_string
    "#{details["organization_reference"]}"
  end

  def enrichment_tasks
    ["enrich/net_block"]
  end

  ###
  ### SCOPING
  ###
  def scoped?(conditions={}) 
    return true if self.seed
    return false if self.hidden # hit our blacklist so definitely false

    # Check types we'll check for indicators 
    # of in-scope-ness
    #
    scope_check_entity_types = [
      "Intrigue::Entity::Organization",
      "Intrigue::Entity::DnsRecord",
      "Intrigue::Entity::Domain" 
    ]

    ### CHECK OUR SEED ENTITIES TO SEE IF THE TEXT MATCHES
    ######################################################
    if self.project.seeds
      self.project.seeds.each do |s|
        next unless scope_check_entity_types.include? s.type.to_s
        if "#{details["whois_full_text"]}" =~ /[\s@]#{Regexp.escape(s.name)}/i
          return true
        end
      end
    end

    ### CHECK OUR IN-PROJECT ENTITIES TO SEE IF THE TEXT MATCHES 
    #######################################################################
    self.project.entities.where(scoped: true, type: scope_check_entity_types ).each do |e|
      # make sure we skip any dns entries that are not fqdns. this will prevent
      # auto-scoping on a single name like "log" or even a number like "1"
      next if (e.type == "DnsRecord" || e.type == "Domain") && e.name.split(".").count == 1
      # Now, check to see if the entity's name matches something in our # whois text, 
      # and especially make sure 
      if "#{details["whois_full_text"]}" =~ /[\s@]#{Regexp.escape(e.name)}/i
        return true
      end
    end

    # now check more edge cases

    ### CHECK OUR IN-PROJECT ENTITIES TO SEE IF THE ORG NAME MATCHES 
    #######################################################################
    if details["organization"] || details["organization_name"]
      self.project.entities.where(scoped: true, type: scope_check_entity_types ).each do |e|
        # make sure we skip any dns entries that are not fqdns. this will prevent
        # auto-scoping on a single name like "log" or even a number like "1"
        next if (e.type == "DnsRecord" || e.type == "Domain") && e.name.split(".").count == 1
        # Now, check to see if the entity's name matches something in our # whois text, 
        # and especially make sure 
        if details["organization"] || details["organization_name"] =~ /[\s@]#{Regexp.escape(e.name)}/i
          return true
        end
      end
    else
      return true if (!details["whois_full_text"] && details["cidr"].to_i > 8)
    end

  # if we didnt match the above and we were asked, it's false 
  false
  end


end
end
end
