# CloudKit Syncronizer/Manager

These files shows my process to create a cloud kit manager to sync the CodeData database for multiple users to the cloud and then each users' connected device will sync to the current data.

Care was taken to have one database owner as to be able to remove access to data to laid off employees etc.

The data on the local machine awaits for a connection to the internet to sync data and enables the user to work offline if necessary (in flight).

A separate manager takes care of possible conflicts. This manager tries to resolve conflict on a per field data and not the whole record row which is very effective to remove user interactions. Of course a user is notified of such changes if the changed were on his last update. Managing user can also be notified and queried if requested about the changes made and can be re-modified.
 
