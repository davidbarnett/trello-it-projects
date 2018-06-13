require 'rubygems'
require 'active_support/time'
require 'open-uri'
require 'json'

###   Constants   ###
API = 'https://api.trello.com/1/'
###

class Trello

    class Configuration
        attr_accessor :time_zone, :developer_public_key, :member_token, :actions_to_load
    end

    class << self
        attr_writer :configuration
    end

    def self.configuration
        @configuration ||= Configuration.new
    end

    def self.configure
        yield configuration
    end
    
    # A Trello board is a collection of lists.
    class Board 
        attr_accessor :id, :name, :lists, :labels, :members, :cards, :actions_to_load

        def initialize(id)

            # configs
            if Trello.configuration.time_zone.nil?
                Time.zone = 'Pacific Time (US & Canada)'
            else
                Time.zone = Trello.configuration.time_zone
            end
            if Trello.configuration.actions_to_load.nil?
                @actions_to_load = ['createCard', 'commentCard', 'updateCard',  'addMemberToCard', 'removeMemberFromCard', 'updateCheckItemStateOnCard']
            else
                @actions_to_load = Trello.configuration.actions_to_load
            end
            
            @id = id
            load_members()
            load_labels()
            load_lists()
            load_cards()

        end #trello-board-initialize

        def load_members()
            @members = []
            url = "#{API}boards/#{@id}/members?key=#{Trello.configuration.developer_public_key}&token=#{Trello.configuration.member_token}&fields=all"
            results = JSON.parse(open(url).read)

            results.each do |member|
                @members << Trello::Member.new(member['id'], member['fullName'], member['username'], member['avatarHash'])
            end
        end # trello-board-load_members

        def load_labels()
            @labels = []
            url = "#{API}boards/#{@id}/labels?key=#{Trello.configuration.developer_public_key}&token=#{Trello.configuration.member_token}"
            results = JSON.parse(open(url).read)

            results.each do |label|
                unless label["name"].match(/\[private\]/)
                    @labels << Trello::Label.new(label['id'], label['name'], label['color'], label['uses'])
                end
            end
        end # trello-board-load_labels

        def load_lists()
            @lists = []
            url = "#{API}boards/#{@id}/lists?key=#{Trello.configuration.developer_public_key}&token=#{Trello.configuration.member_token}"
            results = JSON.parse(open(url).read)

            results.each do |list|
                unless list["name"].match(/\[private\]/)
                    @lists << Trello::List.new(list['id'], list['name'])
                end
            end
        end # trello-board-load_lists

        def load_cards()
            @cards = []
    
            url = "#{API}boards/#{@id}/cards?key=#{Trello.configuration.developer_public_key}&token=#{Trello.configuration.member_token}&checklists=all&labels=true&actions=#{@actions_to_load.join(",")}"
            
            results = JSON.parse(open(url).read)

            results.each do |card|
                unless card["name"].match(/\[private\]/)
                    @cards << Trello::Card.new(card, self)
                end
            end
        end # trello-board-load_cards

        def find_list_by_id(id)
            @lists.each do |list|
                if list.id == id
                    return list
                end
            end
            return nil
        end # trello-board-find_list_by_id

        def find_card_by_id(id)
            @cards.each do |card|
                if card.id == id
                    return card
                end
            end
        end # trello-board-find_card_by_id

        def find_member_by_id(id)
            @members.each do |member|
                if member.id == id
                    return member
                end
            end
            return nil
        end # trello-board-find_member_by_id

        def find_label_by_id(id)
            @labels.each do |label|
                if label.id == id
                    return label
                end
            end
            return nil
        end

        def find_labels_by_name(regex)
            results = []
            @labels.each do |label|
                if label.name.match(regex)
                    results << label
                end
            end
            results.reverse!
            return results
        end

        def find_lists_by_name(regex)
            results = []
            @lists.each do |list|
                if list.name.match(regex)
                    results << list
                end
            end
            return results
        end

        def search_cards_by_name(q)
            results = []
            @cards.each do |card|
                if card.name.match(q)
                    results << card
                end
            end
            return results
        end # trello-board-search_cards_by_name

    end # trello-board

    class Member
        attr_accessor :id, :full_name, :username, :avatar, :cards, :actions

        def initialize(id, full_name, username, avatar)
            @id = id
            @full_name = full_name
            @avatar = avatar
            @username = username
            @cards = []
            @actions = []

            return self
        end # trello-member-initialize

    end # trello-member

    class List
        attr_accessor :id, :name, :cards

        def initialize(id, name)
            @id = id
            @name = name
            @cards = []

            return self
        end # trello-list-initialize

        def cards_with_member(member)
            results = []
            @cards.each do |card|
                if card.members.include?(member)
                    results << card
                end
            end
            return results
        end

        def cards_with_label(label)
            results = []
            @cards.each do |card|
                if card.labels.include?(label)
                    results << card
                end
            end
            return results
        end

    end # trello-list

    class Card
        attr_accessor :id, :board, :name, :desc, :due, :complete, :slug, :list, :labels, :members, :actions, :checklists, :raw_json

        def initialize(obj, board)
            @id = obj["id"]
            @board = board
            @name = obj["name"]
            @desc = obj["desc"]
            if obj["due"].nil?
                @due = nil
            else
                @due = Time.parse(obj["due"]) 
            end
            @complete = obj["dueComplete"]
            @slug = obj["url"].match(/\/(\d{1,5}\-.*)/)[1]
            @list = board.find_list_by_id(obj['idList'])
            @list.cards << self
            @members = []
            obj['idMembers'].each do |member_id|
                m = board.find_member_by_id(member_id)
                @members << m
                m.cards << self
            end
            @checklists = []
            self.process_checklists(obj)
            @labels = []
            obj['labels'].each do |l|
                # sometimes we have private labels, we don't want nil labels added
                # in their place.
                unless board.find_label_by_id(l['id']).nil?
                    # find the label
                    label = board.find_label_by_id(l['id'])
                    # add the label to the card
                    @labels << label
                    # add the card to the label
                    label.cards << self
                end
            end

            @actions = []
            self.process_actions(obj)

            #@raw_json = obj

            return self

        end # trello-card-initialize


        def process_checklists(obj)
            obj["checklists"].each do |checklist|
                if checklist['name'].match(/\[public\]/)
                    #puts "#{@name}: adding checklist #{checklist['name']}"
                    @checklists << Trello::Checklist.new(checklist, self)
                end
            end
        end # trello-card-process_checklists

        def process_actions(obj)
           
            if obj['actions'].count >= 50
                # When we pull actions from cards, it's capped at a limit of 50 actions.  If we see
                # 50 actions when processing, it's likely there are more so we're going to intercept
                # and make sure we get all the actions. Additionally, we need to loop through pages
                
                limit = 1000
                x = []
                record_count = limit
                page_value = ""

                #TODO: We're going to have to track API calls to respect rate limiting and deal with any exceptions.
                until record_count < limit do
                    next_page = JSON.parse(open("#{API}cards/#{@id}/actions?key=#{Trello.configuration.developer_public_key}&token=#{Trello.configuration.member_token}&filter=#{@board.actions_to_load.join(',')}&limit=#{limit}#{page_value}").read)
                    x.concat(next_page)
                    record_count = next_page.count
                    page_value = "&before=#{next_page.last['id']}"
                end
            else
                x = obj['actions']
            end

            x.each do |action|
                if Trello.configuration.actions_to_load.include?(action['type'])
                    # Add public comments
                    if action['type'] == 'commentCard' && action['data']['text'].match(/\[public\]/)
                        @actions << Trello::Action.new(action, self)
                    end
                    # Add changes in due dates or changes in lists
                    if action['type'] == 'updateCard' && ( action['data']['old'].include?('due') || action['data']['old'].include?('idList') )
                        @actions << Trello::Action.new(action, self)
                    end
                    # Add checklist items for public checklists that are still active on this card
                    if action['type'] == 'updateCheckItemStateOnCard' && action['data']['checklist']['name'].match(/\[public\]/) && !find_checklist_item_by_id(action['data']['checkItem']['id']).nil?
                        @actions << Trello::Action.new(action, self)

                        # Populate the complete_date attribute of the checkitem for completed items
                        if action['data']['checkItem']['state'] == 'complete' && !action['date'].nil? && !find_checklist_item_by_id(action['data']['checkItem']['id']).nil?
                            find_checklist_item_by_id(action['data']['checkItem']['id']).complete_date = Time.parse(action['date'])
                        end
                    end 
                    # Add card creation events
                    if action['type'] == 'createCard' || action['type'] == 'addMemberToCard'  || action['type'] == 'removeMemberFromCard'
                        @actions << Trello::Action.new(action, self)
                    end
                end
            end
        end # trello-card-process_actions

        def milestones()
            @checklists.each do |checklist|
                if checklist.name.downcase == "milestones"
                    return checklist
                end
            end
            return nil
        end # trello-card-milestones

        def find_checklist_item_by_id(id)
            @checklists.each do |checklist|
                checklist.items.each do |item|
                    if item.id == id
                        return item
                    end
                end
            end
            return nil
        end # trello-card-find_checklist_item_by_id

        def find_labels_by_name(regex)
            results = []
            @labels.each do |label|
                if label.name.match(regex)
                    results << label
                end
            end
            return results
        end

    end # trello-card

    class Action
        attr_accessor :id, :card, :type, :datetime, :member

        def initialize(obj, card)
            @card = card
            @id = obj['id']
            @type = obj['type'] 
            @member = card.board.find_member_by_id(obj['idMemberCreator'])
            @datetime = Time.zone.parse(obj['date'])
            @data = obj['data']
            @obj = obj

            if @member.nil?
                # The member does not exist, maybe he's been inactivated but he still has an action history, we need to add them.
                @member = Trello::Member.new(obj['memberCreator']['id'], obj['memberCreator']['fullName'], obj['memberCreator']['username'], obj['memberCreator']['avatarHash'])
            end
            
            @member.actions << self

            return self
        end

        def text
            return self.to_s
        end

        def to_s
            if @type == "commentCard"
                return @data["text"].split('[public]')[-1].strip
            end
            if @type == "updateCheckItemStateOnCard"
                if @data['checklist']['name'].match(/\[public\]/)
                    return @data["checkItem"]["state"] + ' - ' + @data["checkItem"]["name"]
                end
            end
            if @type == "updateCard"
                changed_items = []
                @data['old'].each do |k,v|
                    changed_items << k
                end
                response = ""
                changed_items.each do |x|
                    if x == 'idList'
                        # to account for archived boards
                        if self.card.board.find_list_by_id(@data['old']['idList']).nil?
                            from_board = "unknown board"
                        else
                            from_board = self.card.board.find_list_by_id(@data['old']['idList']).name
                        end
                        if self.card.board.find_list_by_id(@data['card']['idList']).nil?
                           to_board = "unknown board"
                        else
                            to_board = self.card.board.find_list_by_id(@data['card']['idList']).name 
                        end

                        response += "#{@member.full_name} moved this card from #{from_board} to #{to_board}"
                   
                    elsif x == 'due' && @data['old'][x].nil? && !@data['card'][x].nil?
                        response += "#{@member.full_name} added a due date of #{Time.parse(@data['card'][x]).strftime("%m/%d/%Y")}"
                    elsif x == 'due' && !@data['old'][x].nil? && @data['card'][x].nil?
                        response += "#{@member.full_name} removed the due date of #{Time.parse(@data['old'][x]).strftime("%m/%d/%Y")}"      
                    elsif x == 'due' && !@data['old'][x].nil? && !@data['old'][x].nil?
                        response += "#{@member.full_name} changed the due date from #{Time.parse(@data['old'][x]).strftime("%m/%d/%Y")} to #{Time.parse(@data['card'][x]).strftime("%m/%d/%Y")}"
                    else 
                        unless x == "desc"
                            response += "#{x} changed from #{@data['old'][x]} to #{@data['card'][x]}" 
                        end
                    end
                    
                end
                return response
            end
            if @type == "createCard"
                # If a list id doesn't exist, or if the list isn't in this board.
                if @data['list']['id'].nil? || @card.board.find_list_by_id(@data['list']['id']).nil?
                    return "#{@member.full_name} created this project"
                else
                    return "#{@member.full_name} created this project and added it to #{@card.board.find_list_by_id(@data['list']['id']).name}"
                end
            end
            if @type == "addMemberToCard"
                if @member.id != @obj['member']['id']
                    return "#{@member.full_name} added #{@obj['member']['fullName']} to this project"
                else
                    return "#{@member.full_name} joined this project"
                end
            end
            if @type == "removeMemberFromCard"
                if @member.id != @obj['member']['id']
                    return "#{@member.full_name} removed #{@obj['member']['fullName']} from this project"
                else
                    return "#{@member.full_name} left this project"
                end
            end
        end

    end # trello-action

    class Checklist
        attr_accessor :id, :name, :items, :pos, :items, :milestones, :card

        def initialize(obj, card)
            @id = obj['id']
            @name = obj['name'].gsub('[public]', '').strip
            if @name.downcase == 'milestones'
                @milestones = true
            else
                @milestones = false
            end
            @items = []
            @card = card

            process_items(obj)
            @items.sort_by! {|item| item.pos }

            return self
        end

        def process_items(obj)
            obj['checkItems'].each do |item|
                @items << Trello::ChecklistItem.new(item, self)
            end
        end
    end # trello-checklist

    class ChecklistItem
        attr_accessor :id, :name, :state, :complete, :pos, :target_date, :checklist, :complete_date, :action

        def initialize(obj, checklist)
            @checklist = checklist
            @id = obj['id']
            if @checklist.milestones
                if obj['name'].match(/(.*)\[(.*)\]/)
                    @name = obj['name'].match(/(.*)\[(.*)\]/)[1]
                    @target_date = obj['name'].match(/(.*)\[(.*)\]/)[2]
                else
                    @name = obj['name']
                    @target_date = nil
                    #puts "WARN: #{@checklist.card.name}:#{@checklist.name} - #{obj['name']} (invalid format - no date)"
                    # TODO: Alert Owners of formatting issue?
                end
            else
                @name = obj['name']
                @target_date = nil
            end
            @state = obj['state']
            if obj['state'] == 'complete'
                @complete = true
            else    
                @complete = false
            end
            @complete_date = nil
            @pos = obj['pos'].to_f

            return self
        end # trello-checklistitem-initialize
    end

    class Label
        attr_accessor :id, :name, :color, :uses, :cards
        
        def initialize(id, name, color, uses)
            @id = id
            @name = name
            @color = color
            @uses = uses
            @cards = []
        end 

    end # trello-label
 end # trello