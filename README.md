iPhoto2Flickr
=============

Command-line tool on Mac OS X to upload your iPhoto albums along with their photos and videos to Flickr.

Tested succesfully with iPhoto 9.6 on Max OS X Yosemite 10.10.1 using XCode 6.1.1.

Installation
------------
Clone the repository. Open the file <code>iPhoto2Flickr.xcworkspace</code> in XCode. Click the Run button.

The first time, at the beginning, you'll be requested to authorize the app to access your app on Flickr and to enter the verification token from Flickr in the app.


What it does
------------
- Uploads your iPhoto albums to Flickr.
- Copies your photos/videos title, description, and faces from iPhoto to Flickr.
- Copies the album title image.
- Resumes where it stopped in case it is interrupted.

The idea is that you can schedule it as a regular job to keep your Flickr account in sync with your iPhoto library.


How it works
------------
- Written in Objective-C as a command-line tool
- Reads iPhoto's AlbumData.xml file
- Uploads images/videos to Flickr using <a href="https://github.com/lukhnos/objectiveflickr">ObjectiveFlickr</a> to connect to the API
- Photos on Flickr get a machine tag for identifying them (iPhoto2Flickr:masterGuid=xxxx)
- Albums are identified using their title


Known issues / Limitations / Backlog
------------------------------------
- Most videos are uploaded properly, but certain types of videos cannot be uploaded (Filetype was not recognised)
- Metadata is set properly on Flickr when uploading, but not updated afterwards, e.g. if changed in iPhoto
- Does not delete photos/videos from Flickr once they have been deleted from iPhoto
- Flickr photosets order does not necessarily reflect the iPhoto albums order
- Album description is not copied (information not available in AlbumData.xml)
- "Date Taken": Didn't test if the timestamp from iPhoto is correctly set on Flickr
- Currently no parameter/setting can be passed to the app, e.g. to display or hide verbose status information or to specify another Flickr API key + secret
- An overall progress bar with ETA is missing
- More generally, this is a command-line tool; a proper GUI would be helpful to most users!
- Error handling is missing e.g. network connection lost, Flickr timeout, retry on error
- The whole coding is synchronous - It could benefit from being migrated to functional reactive programming (while abiding to Flickr's 3600 requests/hour limit)
