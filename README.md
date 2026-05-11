# koreader-frankenpatches
"frankenpatches" because every little coding experiment i take on is a frankenstein mix of borrowed code, gpt code and some of my own. :D

# [2-cvs-receipt-frankenpatch.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-cvs-receipt-frankenpatch.lua)
![511376917-ec9cebc3-1a03-4bb7-ad8d-b1f25fc5a6da](https://github.com/user-attachments/assets/79e27a09-cbae-4f94-8396-4d65d7295011)

a little box that you can summon with a corner tap (or any other gesture) from reader view. shows your chapter progress, book progress and time left in each. i made this because i wanted to keep my reader view squeaky clean but also easily see how far into the book i am. 

INSTALLATION: drop the .lua into the koreader/patches folder. set up a gesture to trigger the 'cvs receipt' action in 'general' category. 

# [2-kobo-style-sleepscreen-banner.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-kobo-style-sleepscreen-banner.lua)
![download](https://github.com/user-attachments/assets/ca5821e9-5722-4969-ac52-be7f7431a006) 
![93746](https://github.com/user-attachments/assets/1d43d728-ecd2-4911-8b73-6805cb3dac6a)

i wanted a simpler kobo style lockscreen tag, so i made one. 
this is a direct redesign of the inbuilt 'banner' style sleep screen message. i gave it a new design and added the option to show a random highlight from the current book. 

INSTALLATION:
drop the .lua file into koreader/patches directory and restart koreader.

CONFIGURATION:
to edit the small text field (stats text), go to: `Settings` > `Screen` > `Sleep Screen` > `Sleep screen message` and set up a custom sleep screen message. click the 'info' button under the text entry box to see the pattern you need to use. for eg, "%T" will show as book title, "page %c of %t" will show as 'page 1 of 400' etc. make sure that the 'container type' is set to 'banner' in the same menu. also tweak the 'vertical position' and 'opacity' to your liking.

the large text field (title text) defaults to book title. it can be configured by changing the 'title_text' value in the second line of the code. follow the same pattern as the default sleep screen text. 
the background color of the tag can also be changed to black in the same code block, along with a couple other parameters.

NOTES:
some specific parameters like chapter title, time left in book/chapter etc. will only show if the device is locked WHEN THE BOOK IS OPEN. if locked with book closed, they'll show up as N/A. this is expected koreader behaviour.
also it goes without saying that the patch looks best when 'stretch wallpaper to fit screen' is enabled.

# [2-mini-receipt-frankenpatch.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-mini-receipt-frankenpatch.lua)
<img width="600" height="345" alt="528862839-d72382c7-81b7-4266-8930-b127a392e340" src="https://github.com/user-attachments/assets/bf50167a-770b-4eee-bb9f-49ed7b9a9055" />

made this because at one point i found cvs receipt to be a little too big and cluttered.

INSTALLATION: drop the .lua into the koreader/patches folder. set up a gesture to trigger the 'mini receipt' action in 'general' category. 

# [2-mosaicmenu-hide-bookstatusicons.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-mosaicmenu-hide-bookstatusicons.lua)
<img width="674" height="328" alt="before" src="https://github.com/user-attachments/assets/4dac7c05-ba31-4c6c-96a1-d9895b9c2759" />

hides those pesky dogears that show up on the bottom right corner of the book cover in mosaicmenu after the book has been opened.

INSTALLATION: drop the .lua into the koreader/patches folder.

# [2-pageno-in-subtitle.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-pageno-in-subtitle.lua)
<img width="600" height="121" alt="FileManager_2026-03-09_160931" src="https://github.com/user-attachments/assets/0829d835-69ab-4e0a-a3ce-9d34e86a16a6" />

appends 'Page x of y' to the folder name in filemanager view. very helpful if you're using the 'hide pagination' type patches that have been popular recently.

INSTALLATION: drop the .lua into the koreader/patches folder and restart.

# [2-profile-update.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-profile-update.lua)
<img width="971" height="425" alt="asdfasdf" src="https://github.com/user-attachments/assets/1a227bbf-0c46-437c-9ba4-44f044a4a00a" />

- adds 'Update' option to profile submenu.
- adds 'Apply Profile' dispatcher action that shows a list of all saved profiles.

INSTALLATION: drop the .lua into the koreader/patches folder and restart.

# [2-reading-insights-popup.lua](https://github.com/zenixlabs/koreader-frankenpatches-public/blob/main/2-reading-insights-popup.lua)
<img width="600" height="800" alt="FileManager_2026-01-28_184220" src="https://github.com/user-attachments/assets/74ac45ab-28f4-4fc6-b190-9d8f74f2a820" />

CREDITS: this is a modified version of the 'reading insights popup' userpatch made by @quanganhdo  (https://github.com/quanganhdo/koreader-user-patches/).

a window that displays your reading streaks, monthly reading hours, monthly reading days, pages read in a year etc.

INSTALLATION:  drop the .lua into the koreader/patches folder. set up a gesture for the 'Reading statistics: reading insights' action in 'General' category.


