# Mercury
A simple file exchange server for home and small organisations.

# Mission Statement
Exchanging files within a private network or via the internet is, under some circumstances, still challenging. Mercury is going to be a file exchange server with following features:

* Exchange files __without the need to create an account__ at any service provider
* Use __any device with a web browser__, like your phone, tablet, pc,... (no additional software requiered)
* Run within your own network, i.e. a single board computer

## No-Goals
Marcury is not trying to relpace any of the following solutions:

* File synchronisation: Marcury is not synchronising any files, rather use [Syncthing](https://syncthing.net/) or any public service like Dropbox.
* Network file system: Mercury is not a network file system like NFS, SMB, WebDAV... in contrary Mercury should allow file exchange without managing user accounts.

# Planned Features
To fulfill the set goals following features should be implementd:

* Easy to use web UI for file upload and download (done)
* Hidden files, allow access only with direct link or secret file ID
* Custom data retention time on file upload
* Malware check on file upload (done)
* Optional password protection
* File and data set size limits (done)
* Filtering by name, type, tag
* Directory support (done)
* Access to datasets from public internet (IP restricted)

# Ideas

* Display download links as QR codes to share files on mobile devices
* Configureable tag constraints
* Support large files (> 2GB) by automated file splitting on the client side
* Timed availability of uploaded files, so the file becomes available only at a previously specified date and time
* Maximum number of wrong password attempts on password protected files
* Data encryption at rest
* Email notifications on uploaded files, e.g. on download event, clean up, failed authorisation attempt,...
* Checksum to verify file identity
* Upload links to allow uploads from public internet
* Mutable data sets, for multiple users to add / remove data to same data set
* Delete option
* Optional account

# Architecture

## System Context

![System Context](/doc/System%20Context.svg "System Context")

## Component Diagram

![Component Diagram](/doc/Component%20Diagram.svg "Component Diagram")