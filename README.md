kube-resource-calc 

>it's little tool for resource limits calculation of kubernetes deploys.

Enjoy the to use, comment and pull requests!:)

TODO:
- [ ] fix no replicas for DaemonSets
- [ ] avoid to run kubectl more one tims (move the most of logic to jq)
- [ ] ability to choose cluster contects
- [ ] rewrite in python/go
- [ ] kube state metrics: query workload resource usage stats
- [ ] prometheus support: query long time workload resource usage stats

Output example:

![image](https://user-images.githubusercontent.com/28926495/181489927-ea8129e9-39bb-4488-a04a-7e5f99939fd2.png)

	
	
	
