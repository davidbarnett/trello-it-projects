# Activate and configure extensions
# https://middlemanapp.com/advanced/configuration/#configuring-extensions

activate :autoprefixer do |prefix|
  prefix.browsers = "last 2 versions"
end

# Layouts
# https://middlemanapp.com/basics/layouts/

# Per-page layout changes
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false

# With alternative layout
# page '/path/to/file.html', layout: 'other_layout'




# Proxy pages
# https://middlemanapp.com/advanced/dynamic-pages/

# proxy(
#   '/this-page-has-no-template.html',
#   '/template-file.html',
#   locals: {
#     which_fake_page: 'Rendering a fake page with a local variable'
#   },
# )

# Helpers
# Methods defined in the helpers block are available in templates
# https://middlemanapp.com/basics/helper-methods/

# helpers do
#   def some_helper
#     'Helping'
#   end
# end

# Build-specific configuration
# https://middlemanapp.com/advanced/configuration/#environment-specific-settings

configure :build do

  # load environment variables
  activate :dotenv, env: '.env.build'

  # use the custom library
  require './lib/trello'

  config[:sitetitle] = "Trello IT Projects"


  # configure parameters of the custom library
  Trello.configure do |config|
    config.time_zone = 'Pacific Time (US & Canada)'
    config.developer_public_key = ENV['developer_public_key']
    config.member_token = ENV['member_token']
    config.actions_to_load = ['createCard', 'commentCard', 'updateCard',  'addMemberToCard', 'removeMemberFromCard', 'updateCheckItemStateOnCard']
  end

  # https://trello.com/b/mH38wPIp/trello-it-projects is the url of the board we want, grab the ID
  board = Trello::Board.new('mH38wPIp')

  # load the board into a variable that can be accessed in pages
  config[:board] = board


  # Loop through cards, make individual project pages through
  # middleman's proxy feature.
  board.lists.each do |list|
    unless list.name.match(/^Done/)
      list.cards.each do |card|
        proxy "/project/#{card.slug}/index.html", "/project/index.html", :locals => { :project_id => card.id, :board => board}, :ignore => true
      end
    end
  end

  # Same as above, go through members and make a members page.
  board.members.each do |member|
    proxy "member/#{member.username}/index.html", "/member/index.html", :locals => { :member_id => member.id, :board => board }, :ignore => true
  end

  # Same as above, go through lables and make a labels page.
  board.labels.each do |label|
    proxy "/label/#{label.id}/index.html", "/label/index.html", :locals => { :label_id => label.id, :board => board }, :ignore => true
  end

  # minify css/javascript, for efficiency
  activate :minify_css
  activate :minify_javascript
end
