This Docker image simplifies the setup of Kannel, an open source WAP Gateway, and Mbuni,
an open source MMS Gateway, based off Kannel. It also includes a patched version of
osmo-ggsn that passes PDP Context information to Mbuni so MMS messages can be properly
processed and delivered to devices. OpenVPN is used to allow devices on the Osmocom 
network (subnet 10.10.11.0/24) to interface with services on different systems/containers
(subnet 10.10.10.0/24, managed by OpenVPN) than osmo-ggsn.

Setup is detailed in setup.txt.

Each container's output can be monitored with: docker compose logs -f *,
where * is ggsn, bearerbox, wapbox, mmsc, mmsbox, or smsbox.
(these components are all part of Osmocom, Kannel, or Mbuni. check out their manuals
online for more info on them.)

The MMSC is hosted at 10.10.10.2, port 80. If you are on iOS, you can configure this in:
Settings > (General > Network for older iOS, or Cellular for newer) > Cellular Data
Network > MMSC: 10.10.10.2. 
Using dnscrypt, I also made a DNS cloaking rule to return the MMSC Address for lookups
to the "m.ms" domain, which should also work in the MMSC field on mobiles connected to
the network. More about cloaking later, but you can change this domain by modifying 
wap/dnscrypt/cloaking-rules.txt, then restarting the GGSN container.
NOTE: Some phones require you to prefix the MMSC Address with http:// (e.g. http://m.ms),
and won't work without it (curse the Motorola Flipout for wasting hours of my time!!!).

In addition to having an MMSC component, you can also access WAP services on your phone
through Kannel's WAP Gateway! The IP Address for the WAP Gateway is: 10.10.10.3.
* This will also be your "IP Address" for old phones using WAP to receive MMS *

Make sure you also set the correct number in Phone > My Number to ensure MMSs are
displayed properly. If it's wrong, your number will be listed as a recepient in group
MMSs instead of it only showing numbers other than your own, and you'll receive your own
messages in those groups.

The flow of MMS for debugging or people just interested:
- Sending mobile connects to MMSC (Mbuni) at 10.10.10.2:80
- Sending mobile sends MMS message (m-send-req)
- MMSC confirms MMS send (m-send-conf)
- MMSC adds MMS to queue
- On queue timer, MMSC requests a WAP Push (yes, WAP, even to new phones. It's a special
  SMS notification) send to receiving MSISDNs.
- Kannel accepts the SMS send (Accepted for delivery), and connects to osmo-msc's SMPP
  server.
- osmo-msc accepts the SMPP message, and sends the WAP Push to the receiving mobile.
- The receiving mobile receives the message, and attempts to retrieve it at the URL
  provided in the WAP Push message (unless the MMSC IP is locked) (HTTP Get)
- MMSC accepts connection, and sends MMS message data to receiving mobile.
  (m-retrieve-conf)
- The message finishes downloading, and the phone notifies the user of a new message.

Some notes about using this image (please read!):
MMS is done (almost) entirely over data, so the only thing the MMS Gateway knows about
a mobile when it sends a message is its IP Address. The gateway relies on messages from
the patched osmo-ggsn, each containing an IP Address/MSISDN pair, to be sent to it as
subscribers connect to the network (or more accurately as PDP contexts are created) so it
can determine the sender of a message's MSISDN, and pass that MSISDN to the recepients so
they know who sent the message. Point is, if the messages you receive have a sender of
"/TYPE=PLMN", this is a sign that Mbuni couldn't determine a sender's phone number from
the sending IP Address. The most likely explanation is that Mbuni was started after the
phone activated its PDP context, so Mbuni couldn't have received the PDP context
information. Try toggling Airplane Mode on the sending phone for around 30 seconds, then
disabling it so the PDP context information can be refreshed and sent to Mbuni.

Because 2G data is unfortunately painfully slow, it is normal for images to take a
painfully long time to send, and even fail for large images. There isn't really a way
around this, unless you have a way of either speeding up the GPRS/EGPRS network (adding
more data timeslots, calibrating link quality ranges in osmo-pcu, enabling 11-bit burst
support, see osmo-pcu manual 8.8.1 for this) or compressing the images on the phone's
end. My iPhone 7 marks a message "Not Delivered" after just about 120 seconds, so on a
full speed connection (MCS-9), you won't be able to upload anything larger than 700KB.
If osmo-pcu ever gets multi-slot uplink support, this may allow uploads of up to 1.5MB on
an MCS-9 connection over two minutes (maybe more if the phone has a higher MS class,
every iPhone I've tested has a class of 10 which gives at max 2 uplink slots), which may
alleviate the issue.
Make sure your gamma parameter and link-quality-ranges in osmo-pcu are also calibrated
for the best speeds with your setup; my uplink was really unstable a lot of the times
before I played with those options, because my phones were constantly transmitting on
full power on the uplink, which caused clipping on the receivier and dropped my link
quality significantly. After adjusting this and toggling airplane mode on my mobiles,
the average uplink speed and link quality increased significantly. Adjusting the
window-size option can also help your downlink speeds.
It might take a couple of sends for the settings to go into effect and your phone's
upload speed to kick into gear.
Also sometimes the phones will just stop uploading for no reason and eventually fail. I
seriously have no idea why this happens. Toggling airplane mode helps sometimes.
On another note, videos should actually send fine! Yes, they're awful quality 3GPP
videos, but they're highly compressed on the mobile side, so they actually send pretty
quick over EDGE, even quicker than some images from phones that can send them.

One big feature that I'm sure people want to utilize with this is Group Messaging.
Unfortunately, specifically on iOS, it can be a somewhat tricky process to set up.
This is because iOS specifically disallows Group Messaging in the Carrier Bundles for
test SIMs (where the IMSI is 00101....), but in bundles where Group Messaging is allowed,
like AT&T, you can't edit the MMSC settings; it is hardcoded to a specific address. When
you don't have the "Group Messaging" setting toggled, every MMS you receive with multiple
recepients appears as a one-on-one chat with the sender, like a normal mass SMS.
So how can you get around this? I've found two options:

1) On older iOSs (at least iOS 6 and below), I've noticed that when I put in a SIM where
I can toggle the "Group Messaging" setting, and then I replace it back with a test SIM,
the setting persists even though the toggle is gone, and group messages show as having
multiple receipients and you can send to all the recepients. This toggle seems to persist
for a fairly long time (after around a month, my iPhone 3G started receiving group MMSes
as individual again).

2) Phones using AT&T IMSIs (310410...) have the Group MMS slider unlocked, but take away
the option to edit the MMSC settings.
But since we're in control of all the phones' traffic, we can redirect DNS requests to a
local DNS server so the phones will send the MMS traffic to our local server! For this, I
use an iptables rule to redirect DNS traffic to 8.8.8.8 (you can also redirect a
different DNS IP Address to the local server, see the rule I have setup in
wap/osmocom/iptables_run.sh with 8.8.8.8 for an example) to our own DNS server, and using
the "cloaking" feature of dnscrypt-proxy, we can redirect lookup requests to some common
MMSC addresses to our own server. You can add your own redirect rules in 
wap/dnscrypt/cloaking-rules.txt; the local MMSC address is 10.10.10.2. Make sure you
restart the ggsn container after any changes to the iptables/cloaking rules.
*The reason I setup my own DNS server rather than using iptables rules to redirect
traffic, which does work for some hardcoded MMSCs, is because DNS lookup requests to some
of the hardcoded MMSCs don't return an A record on normal public DNS servers. When phones
don't get an IP Address for their lookup request, they'll fail sending, and there's no 
traffic to redirect.

If your phone is sending a dead UA Profile URL, you need to setup a UAProf
Override in wap/mbuni/uaprof_overrides.txt. The UA Profile URL (or UAProf URL) is a
link that is sent by a mobile upon message retrieval as an HTTP header (X-Wap-Profile)
that contains an XML-like file telling the MMSC what file formats it can receive, and how
it should be encoded. If this link is dead, the MMSC will not know how to encode the
message for the receiving phone, and you will probably receive a message like:
"Unsupported object (content type image/jpeg) removed"
upon retrieval. I have the UA Prof override for the dead iOS UA Prof URL already setup,
but to find the URL your phone is sending, you will need to check the logs of the mmsc.
If you look through the logs after the phone tries to retrieve a message, you should be
able to see what URL the phone is sending, and if Mbuni is able to read data from it. If
not, or if it's complaining about not having SSL enabled, (I couldn't figure out how to
build Mbuni with SSL support, so it might have trouble with HTTPS sites) you'll need to
setup a UAProf override. The original UAProf might be able to be found by plugging in the
URL into the Internet Archive or searching for an updated version/URL. You might also
need to make your own, if so I have two examples of profiles in the wap/mbuni folder.
Once you have the content, link to it in the wap/mbuni/uaprof_overrides.txt file (see my 
existing iOS/Samsung record for an example) and restart docker-wap-mmsc-1 to load the
override.
Using an override is also useful to allow phones to accept content of certain types if
you know they can, but have it disabled in the UAProf. My SGH-X427M was actually able to
accept voice messages (audio/amr), but the server wouldn't send it because it was not
specified in the default UAProf.
More info on UA Profiles:
https://en.wikipedia.org/wiki/UAProf

Even though MMSCs are supposed to dynamically scale/convert MMS messages to support the
capabilities of the receiving phone, some phones (e.g. my SGH-X427M) won't even try to
download an MMS message from the MMSC if the message size indicated in the WAP Push is
larger than a certain amount. For that reason, I added the "max-wap-msize" configuration
option in Mbuni, that will limit the message size reported in the WAP Push to that value.
It is set at 30720kb by default, for the Samsung SGH-X427M's reported maximum message
size.

One of the patches I made in this most recent patch was to downscale images to be smaller
than the phones requested MmsMaxMessageSize. Two notes about this: it does try to split
the size between all of the images, so if you send multiple images in one MMS, the
receiving phone will have a drop in quality that gets worse the more images you send.
Second, it only splits it between images, and doesn't account for the size of audio or
anything else in the message. So there's a chance that if you attach multiple images on a
message, and then something else like audio or a bunch of text, the server will void the
message because it exceeded the phone's requested size. To get around this, try sending
images separately, or adjusting the MmsMaxMessageSize in the UAProf override.

Finally, if you want to sniff traffic on the GGSN image using Wireshark, you can do so
using something like Edgeshark. You can even save media being sent to the server by
exporting the Hex Stream of the media when the phone sends a m-send-req.
An example of saving an image/other content sent in an MMS Message (make sure you capture
the entire message send process):
https://www.youtube.com/watch?v=4lZMX61r9MI
