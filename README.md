# Re-tor
Redirect all traffic of your linux through tor (The Onion Router)

RETOR
	
Instructions:
	
> 1. Run Tor: 
	```
	service tor start
	```
	> 2. Set permissions and run script as root: 
	```
	chmod +x re-tor.sh
	sudo ./re-tor.sh --start
	```
	> 3. Stop script: 
	```
	sudo ./re-tor.sh --stop
	```
