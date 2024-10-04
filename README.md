# Datto RMM component Veeam Backup & Replication

UPDATE 04/10/2024:

Corrected documentation in progress
English translation in progress

---------------------------------------------------------------------------

Warning!
This component is a Beta for internal use, proper functionality cannot be assured.

Warning!
The usrThreshold doesn't represent "Hours to wait before alerting on lack of backups," as shown in the screenshot. Instead, it defines the time window the script uses to check event log entries.
It's an error caused by copying the Datto component used as an example for creating this one for Veeam. I'm lazy and don't plan to redo the screenshots.

I created two scripts, one for Backup and Replication (tested with the community edition) and one for Veeam Agent. The second script checks if there are no failed or completed backup events for 7 days before triggering an alert.

User Defined Field:
![immagine](https://github.com/user-attachments/assets/c9a054bb-a284-4bf3-85d2-987bdaf9aded)


Component Setup:

You need to paste here the ps script
![immagine](https://github.com/user-attachments/assets/b0044e6a-73eb-4999-a743-0e206d3c4f2e)
![immagine](https://github.com/user-attachments/assets/eb6d892e-e1cb-4636-a340-995915f79f34)

Policy Setup:

Make a filter:
![immagine](https://github.com/user-attachments/assets/1ffd6a62-ff92-497b-afd6-162bf66f4c9a)


And the policy
![immagine](https://github.com/user-attachments/assets/09656e17-3b63-43bb-b83e-c1adf9cd93a9)


![immagine](https://github.com/user-attachments/assets/8a61aaff-0aa8-4bfc-a3df-305a66aab79d)
![immagine](https://github.com/user-attachments/assets/46a46fed-01f1-4b76-a615-82b87e68c9a4)
![immagine](https://github.com/user-attachments/assets/7aebee9e-7b09-4b72-9838-a67fc2b46668)
![immagine](https://github.com/user-attachments/assets/dc729b17-110b-4543-bdf9-fc694e901c2f)
