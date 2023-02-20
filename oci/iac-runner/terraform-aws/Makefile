Makefileall:
	cp -av ~/.terraform.d/ .
	sudo docker build --network host --no-cache -t artifact.onwalk.net/devops/iac-runner:latest .
	sudo docker push artifact.onwalk.net/devops/iac-runner:latest 
