# Mercury
A simple file exchange server for home and small organisations.

# Mission Statement
Exchanging files within a private network or via the internet is, under some circumstances, still challenging. Mercury is a file exchange server which brings your users the following possibilities:

* Exchange files __without the need to create an account__ at any service provider
* Use __any device with a web browser__, like your phone, tablet, pc,... (no additional software requiered)
* Run it within your own network, if you want to

## No-Goals
Marcury is not trying to relpace any of the following solutions:

* File synchronisation: Marcury is not synchronising any files, rather use [Syncthing](https://syncthing.net/) or any public service like Dropbox.
* Network file system: Mercury is not a network file system like NFS, SMB,... in contrary Mercury should allow file exchange without managing user accounts.

# Planned Features
To fulfill the set goals following features should be implementd:

* Easy to use web UI for file upload and download
* Hidden files, allow access only with direct link or secret file ID
* Custom data retention time on file upload
* Malware check on file upload
* Optional password protection and data encryption