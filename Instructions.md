Instructions - 

Plan - We want to create a fully automated testing framework for new type of testing - "Component Based Testing" custom designed for Essent. Our goal is to define a framework which will automate 100% of testing lifecycle, only test script creation and maintenance will be taken care by human testers (due to it's human thinking and logic) 
Basic expectations in framework - 
1. Create test cases by humans with appropriate logic and validation points 
2. In case of TOSCA - Put completed test cases in TestEvents | In case of API - Design a postman collection and export in api_tests.json file and keep in GitLab repo
3. Gitlab will trigger its automated pipeline every midnight
4. Gitlab will use Group inherited and Project specific variables to match and fill variables.
5. Our organization have different ARTs (Agile release trains). Within each art we have different teams. Each and every team is self sufficient means they have their 1 developer, 1 tester, 1 scrum master, 1 Product Owner
6. Each of such team have their own specific work area on which this entire team work together. Obviously there will be some cross team communication on daily bases due to dependency of one team on another.
7. We want out framework to be used bye ach and every team.
8. We are going to divide work area of a team in Domains and further in Components. Think Domain like a parent folder and Component like a sub-folder. There might be multiple Domains and every Domain might have multiple underlying Components. By doing this we are going to achieve distinctive work area of every team so they can be confident on health of their each Component and subsequently on health of their Domain as well. By doing this we can achieve very perfect confidence on testing life cycle.


Tools we use - We are going to use Tricentis TOSCA for SAP GUI and SAP Fiori script building and Postman Collection for API test cases. We have not defined anything else but we want this framework be adaptive for Playwrite and other testing tools as well. Basically a framework independent on testing tool.

What are we doing now? -
For TOSCA test cases - we are using TOSCA's predefined API calls provided by Tricentis to call TOSCA Server and execute appropriate TestEvent. So we have API calls of TOSCA in gitla just to invoke TOSCA Server. So TOSCA scripts are by default placed in Tricentis server database and we are using Tricentis API calls to invoke them.
For API testing  - We are exporting API requests from Postman to api_tests.json file and trigger it in pipeline. 
 
Some examples of uur GitLab folder structure - 
SAP/ComponentTesting/CrossComponents/Heartbeat
Note: CrossComponents == Domain && Heartbeat == Component within Domain

SAP/ComponentTesting/BillingInvoicing/YearlyAdvice
Note: BillingInvoicing == Domain && YearlyAdvice == Component in BillingInvoicing

SAP/ComponentTesting/SharedResources/scripts/
Note: SharedResources == Project && scripts == a folder for reusable file required in yml

You can apply same logic on folder structure screenshot as well.

Term Domain and Component is very much important and case sensitive as this is going to act as a primary key to distinguish tosca test cases.
Domain name is none other than TestEvent name and Component name is ExecutionList name. and these names are important to identify which execution list has to be triggered.
Every Component will have it's dedicated yaml file kept inside of it. Some Components might have api_tests.json file and some not.

What's next? -
We are using Gitlab runner placed on Essent cloud and our TOSCA server is placed on EON cloud and DEX agent is placed on Essent Cloud so we need to use certificates and proxy for communication.
Once we set API and TOSCA flags as true, pipeline will execute on set time. this will trigger DEX agent, DEX agent will communicate with TOSCA Server and execution will start. When execution finishes pipeline will return .xml files and .json files in GitLab artifacts. These files will be then parsed and logs will be sent to New Relic Dashboard for centralised observability. I have also kept push_to_newrelic.sh file so you can read it.

When it comes to api files, yml files, .sh files. I have not designed any of these files. I have taken help from Claude to design them. SO I have no confidence about best coding standards and practices, also I don't know whether I can make it more efficient or not. The code you can see is given by AI and merged on daily basis so it can look like lot of unnecessary lines and you might also find some other ways to achieve our task in better way. Please feel free to add your suggestions and ask questions if something is not clear to you before assuming anything.


Future Scope -
	a. We still don't have any qTest/Jira/ADO tool for defect management. We should have a list of our test cases somewhere which will automatically show some kind of status like - yet to execute, executed, passed, failed after execution of our pipeline. By this way testers will have centralised defect management tool for defect tracking. Basically we want to develop a framework which is almost fully automated and tester only need to focus on script development. We also don't know how to sync defect management tool with TOSCA execution lists because we don't know how defect management tool and TOSCA is going to sync behind the curtains to keep everything updated. Testers are meant to design their scripts and not waste their time on defect analysis and dashboarding. We want our testers to focus on TOSCA script and api testing calls designing only. planning & monitoring of execution, execution results, result analysis, defect logging, summarization of results and everything will be taken care by pipeline automatically and this is the main goal behind our vision. 
	b. Consider this as a extra improvement/feature which is not necessary to fulfill if hard to implement we can anyways go for simple listing - In defect management tool (it might be anything, whichever is easy to implement as per your thoghts) we want the same folder structure as per gitlab. e.g. - Domain > Component > testcase name, By this tester will be easily able to understand what is failed and where it is. Also we want same folder structure in NewRelic also see graphical representation on each component, each domain and overall testing as well.
	c. We are going to use Gherkin Scenarios for our test case defination
	d. We are thinking to make a dashboard in such a way that each and every team would be able to see their test case pass and failed percentage separately. Cumulative dashboard of everything is for my team only. 
	e. I will keep adding upcoming demands and expectations from my team in future in this section.
