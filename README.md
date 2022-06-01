# Multi Threading Advanced Http Downloader 

TThredingFileDownloader

An Embarcadero Rad Studio/Delphi component (FMX) for parallelized http/https files downloading. Download is parallelized using variable number of threads for acceleration. Several additional options are implemented including:
-	Pause/Resume of the download task at any progress phase. It is far away from a simple a threads suspension, while an internal progression state is automatically saved so the resume can be performed either is the application is close and restarted (a method ResumeFromTempFile permit to restart the download again at any time).
-	Automatic estimation of download speed (instant speed) and remaining time.
-	A sufficiently large set of event permitting a  powerful control of the download progression : OnThredDownloadingData, OnDownloadTerminated, OnDownloadError, OnDownloadInfoUpdate, OnDownloadStarted, OnDownloadPaused, OnCannotResume, OnDownloadResumed, OnDownloadCanceled
-	Detailed download information per individual thread

The included Demo program illustrate the use of the component conjointly with a special progress bar developed for such applications (installation of the package is not necessary to Run the Demo since the creation of the objects is done explicitly in the code).
Tested on Rad 10.2/10.3 and should work for 10.4 and Alexandria. 
Designed for FMX Multi-resolution applications (Windows, Android and Mac …)  


![plot](https://github.com/kamel78/Multi-Threading-Advanced-Http-Downloader-/blob/main/DemoCapture.png)



Remarks and bugs report are welcome.  




