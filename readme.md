#EmailScheduler
This was designed for my server since I use an ISP which blocks port 25 and thus I had to write a work around to send email.

To use, set the dictionary ``emailAddresses`` up with passwords/email addresses and if you want to setup a secure email where the email is removed from gmail after sending, find ``password@birdim.com`` and read the comment.

Use ``com.mrgeckosmedia.EmailScheduler.plist`` to auto start at boot.