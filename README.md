# Datto RMM component Veeam Backup & Replication

UPDATE 04/10/2024:

Corrected documentation in progress

English translation in progress

---------------------------------------------------------------------------

# Warning!
This component is a Beta for internal use, proper functionality cannot be assured.

# Warning!
Any changes made to scripts or policies must be confirmed by returning to the policy section, opening the Veeam policy, and clicking "Save and deploy now"; otherwise, all changes will be ignored.

I created two scripts, one for Backup and Replication (tested with the community edition) and one for Veeam Agent. The second script checks if there are no failed or completed backup events for 7 days before triggering an alert.

# User Defined Field:
![1 - UDF](https://github.com/user-attachments/assets/7671d235-6941-4da4-8970-569185aca5fb)


# Component:

You need to paste here the ps script
![2 - Component](https://github.com/user-attachments/assets/43853be7-5e76-46d1-aac3-30bc1da4f44a)


# Device Filter:
![3- Device Filter](https://github.com/user-attachments/assets/de7a5b63-9979-4167-9bed-0d85a3682d4a)


#Policy:
![4 - Policy](https://github.com/user-attachments/assets/f5f56d64-1bf4-441b-9fdb-ac37ed1aff30)
![5 - Policy](https://github.com/user-attachments/assets/c9e7d026-78e4-4698-9de0-770cccfdee0c)



