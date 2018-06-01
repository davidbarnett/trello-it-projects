

### Getting Started

This project requires Git and Ruby, and then you can:

*Step 1: Install Middleman, Clone the Repo, Install Gems*
> gem install middleman 

> git clone https://github.com/davidbarnett/trello-it-projects.git 

> bundle install 


*Step 2: Get Trello Key/Secret, Create an ENV file
By default, this project uses [this Trello Board](https://trello.com/b/mH38wPIp/trello-it-projects) as a starting point.  You can change this by editing config.rb and changing this line:

 > board = Trello::Board.new('*mH38wPIp*')

 You're going to need to get a 

while you're logged in, visit [Trello's App Key Page](https://trello.com/app-key), copy the Key, and click the Token link in the paragraph below the key.  Then create a new text file called .env.build

> developer_public_key='6kd89skdsf9sdflll3399s989' 
> member_token='908s0fd87s90af8d908fd09fdsf555safds5af5ds5afds'


*Step 3: Build!*

> middleman build

... you should see all the HTML build in the build folder.


### Disclaimer
This is provided as-is with no warranty or support.   I can make no guarantees regarding the fitness of this code to be use for any purpose.  By using this you agree to indemnify, defend, and hold me harmless for any liability incurred by the use of this software. 

/In short, use this software at your own risk/

### Appendix

*Documentation Links*

[Twitter Bootstrap](https://getbootstrap.com/docs/4.1/getting-started/introduction/)

[Middleman](https://middlemanapp.com/basics/install/)