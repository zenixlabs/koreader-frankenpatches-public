# koreader-frankenpatches
"frankenpatches" because every little coding experiment i take on is a frankenstein mix of borrowed code, gpt code and some of my own. :D

# 2-cvs-receipt-frankenpatch.lua
![511376917-ec9cebc3-1a03-4bb7-ad8d-b1f25fc5a6da](https://github.com/user-attachments/assets/79e27a09-cbae-4f94-8396-4d65d7295011)

a little box that you can summon with a corner tap (or any other gesture) from reader view. shows your chapter progress, book progress and time left in each. i made this because i wanted to keep my reader view squeaky clean but also easily see how far into the book i am. 

INSTALLATION: drop the .lua into the koreader/patches folder. set up a gesture to trigger the 'cvs receipt' action in 'general' category. 

# 2-disable-touch-preserve-swipe.lua

basically the koreader equivalent of the 'touch lock' feature in the native kindle ui. disables all touch inputs EXCEPT page-turn swipes. lets you read without having to worry about accidental touches.

INSTALLATION: drop the .lua into the koreader/patches folder and follow the set up instructions inside the file. 

# 2-kobo-style-sleepscreen-banner.lua
![download](https://github.com/user-attachments/assets/ca5821e9-5722-4969-ac52-be7f7431a006)

i wanted a simpler kobo style lockscreen tag, so i made one. 
this is a direct redesign of the inbuilt 'banner' style sleep screen message. meaning i simply gave it a new look. no functional differences other than the extra data field.

INSTALLATION:
drop the .lua file into koreader/patches directory and restart koreader.

CONFIGURATION:
to edit the small text field (stats text), go to: `Settings` > `Screen` > `Sleep Screen` > `Sleep screen message` and set up a custom sleep screen message. click the 'info' button under the text entry box to see the pattern you need to use. for eg, "%T" will show as book title, "page %c of %t" will show as 'page 1 of 400' etc. make sure that the 'container type' is set to 'banner' in the same menu. also tweak the 'vertical position' and 'opacity' to your liking.

the large text field (title text) defaults to book title. it can be configured by changing the 'title_text' value in the second line of the code. follow the same pattern as the default sleep screen text. 
the background color of the tag can also be changed to black in the same code block, along with a couple other parameters.

NOTES:
some specific parameters like chapter title, time left in book/chapter etc. will only show if the device is locked WHEN THE BOOK IS OPEN. if locked with book closed, they'll show up as N/A. this is expected koreader behaviour.
also it goes without saying that the patch looks best when 'stretch wallpaper to fit screen' is enabled.

# 2-mini-receipt-frankenpatch.lua
<img width="600" height="345" alt="528862839-d72382c7-81b7-4266-8930-b127a392e340" src="https://github.com/user-attachments/assets/bf50167a-770b-4eee-bb9f-49ed7b9a9055" />

made this because at one point i found cvs receipt to be a little too big and cluttered.

INSTALLATION: drop the .lua into the koreader/patches folder. set up a gesture to trigger the 'mini receipt' action in 'general' category. 

# 2-mosaicmenu-hide-bookstatusicons.lua
<img width="674" height="328" alt="before" src="https://github.com/user-attachments/assets/4dac7c05-ba31-4c6c-96a1-d9895b9c2759" />

hides those pesky dogears that show up on the bottom right corner of the book cover in mosaicmenu after the book has been opened.

INSTALLATION: drop the .lua into the koreader/patches folder.

# 2-progress-bar-twins.lua
![511379238-d4bd1992-8928-40b1-b30c-6fda269f5115](https://github.com/user-attachments/assets/98ecca69-fbe8-42c7-87ad-609f8c724cb9)

two progress bars side by side. you can choose what progress (chapter or book) to show on each. you can even join them together and mirror one of them so that they essentially look like one regular progress bar that fills from the middle towards the edges. 

INSTALLATION: drop the .lua into the koreader/patches folder. you'll find instructions to customise the patch inside the file.

# 2-reading-insights-popup.lua
<img width="600" height="800" alt="FileManager_2026-01-28_184220" src="https://github.com/user-attachments/assets/74ac45ab-28f4-4fc6-b190-9d8f74f2a820" />

a window that displays your reading streaks, monthly reading hours, monthly reading days, pages read in a year etc.

INSTALLATION:  drop the .lua into the koreader/patches folder. set up a gesture for the 'Reading statistics: reading insights' action in 'General' category.


