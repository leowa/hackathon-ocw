//
//  MainViewController.swift
//  iosclient
//
//  Created by 杨典 on 16/6/19.
//  Copyright © 2016年 星群. All rights reserved.
//

import UIKit
import Alamofire
import SDWebImage

class MainViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var tableView : UITableView!
  
    var courses: NSMutableArray = []
    
    var isInternetConnected = true
    var clearCourses : Bool = false
    
    var selectedCourseId: Int!
    var selectedTitle: String!
    var selectedVideoUrl: String?
    var selectedDescription: String!
    var selectedLink: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        checkInternetConnection()
        
        if(isInternetConnected == true){
            self.getInitId()
            self.jsonParsingFromUrl()
        }
        
        tableView.delegate      =   self
        tableView.dataSource    =   self
        
        self.view.addSubview(tableView)

        // Register custom cell
        let nib = UINib(nibName:"vwTblCell", bundle:nil)
        self.tableView.registerNib(nib, forCellReuseIdentifier: "cell")
        
        tableView.estimatedRowHeight = 90.0
        tableView.rowHeight = UITableViewAutomaticDimension
        
        let tableViewController = UITableViewController()
        tableViewController.tableView = self.tableView;
        
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string:  "下拉刷新")
        refreshControl.addTarget(self, action: #selector(MainViewController.handleRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
        tableViewController.refreshControl = refreshControl;
    }
    
    func checkInternetConnection(){
        if Reachability.isConnectedToNetwork() == true {
            print("Internet connection OK")
        } else {
            print("Internet connection FAILED")
        }
        //If the user is not connected to the internet, you may want to show them an alert dialog to notify them.
        if Reachability.isConnectedToNetwork() == true {
            isInternetConnected = true
            print("Internet connection OK")
        } else {
            self.navigationItem.leftBarButtonItem = nil;
            isInternetConnected = false
            print("Internet connection FAILED")
            let alert = UIAlertView(title: "没有网络连接", message: "请确认您已连接到互联网", delegate: nil, cancelButtonTitle: "OK")
            alert.show()
        }
    }
    
    func getInitId(){
        if (User.sharedManager.userid == 0) {
            //使用deviceid换取userid
            User.sharedManager.deviceid = UIDevice.currentDevice().identifierForVendor!.UUIDString
            //检查本地userProfile文件
            let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
            let documentsDirectoryPath = NSURL(string: documentsDirectoryPathString)!
            let filePath = String(documentsDirectoryPath.URLByAppendingPathComponent("userProfile.json"))
            do{
                let fileContent = try NSString(contentsOfFile: filePath, encoding: NSUTF8StringEncoding)
                let json = try NSJSONSerialization.JSONObjectWithData(fileContent.dataUsingEncoding(NSUTF8StringEncoding)!, options: [])
                let userid = json["userid"] as! Int
                User.sharedManager.userid = userid
            }catch let error as NSError{
                print(error)
                self.getInitFromServer()
            }
        }
    }
    
    func getInitFromServer(){
        var basicProfile = [String: AnyObject]()
        basicProfile["deviceid"] = User.sharedManager.deviceid
        let url = "http://jieko.cc/user"
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do{
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(basicProfile, options: [])
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request, completionHandler: { data, response, error -> Void in
                guard error == nil && data != nil else {                                                          // check for fundamental networking error
                    print("error=\(error)")
                    return
                }
                
                if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(response)")
                }
                
                do {
                    let result = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? [String: Int]
                    User.sharedManager.userid = result!["userid"]
                    self.writeJsonToFile()
                    self.jsonParsingFromUrl()
                } catch let error as NSError {
                    print(error)
                }
                
            })
            task.resume()
        } catch _{
            print("Error json")
        }
    }
    
    func writeJsonToFile(){
        do{
            var json = [String: AnyObject]()
            json["userid"] = User.sharedManager.userid
            json["deviceid"] = User.sharedManager.deviceid
            let text = try NSJSONSerialization.dataWithJSONObject(json, options: [])
        
            let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
            let documentsDirectoryPath = NSURL(string: documentsDirectoryPathString)!
            let filePath = String(documentsDirectoryPath.URLByAppendingPathComponent("userProfile.json"))
            //try text.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding)
            
            let fileManager = NSFileManager.defaultManager()
            fileManager.createFileAtPath(filePath, contents: text, attributes: nil)
        } catch {
            print(error)
        }
    }
    
    func jsonParsingFromUrl(){
        
        var url : String = ""
        if self.title == "推荐" {
            url = "http://api.jieko.cc/user/" + String(User.sharedManager.userid!) + "/Candidates"
        } else {
            url = "http://api.jieko.cc/user/" + String(User.sharedManager.userid!) + "/Candidates/tag/" + self.title!
        }
        url = url.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        
        Alamofire.request(.GET, url).responseJSON { response in
            if response.result.isSuccess {
                self.startParsingCourses(response.result.value!["courses"] as! NSArray)
            }
        }
    }
    
    func startParsingCourses(data: NSArray){
        if (clearCourses == true && data.count > 1){
            courses.removeAllObjects()
            clearCourses = false
        }
        if (data.count > 1){
            for i in 0...(data.count - 1){
                courses.insertObject(data.objectAtIndex(i), atIndex: 0)
            }
        }
        dispatch_async(dispatch_get_main_queue(), {
            
            // DO SOMETHING ON THE MAINTHREAD
            self.tableView.reloadData()
            //self.refreshControl.endRefreshing()
        })
    }
    
    func handleRefresh(refreshControl: UIRefreshControl){
        jsonParsingFromUrl()
        refreshControl.endRefreshing()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return self.courses.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = self.tableView.dequeueReusableCellWithIdentifier("cell")! as UITableViewCell
        
        (cell as! MainTableViewCell).lblTitle.text = courses[indexPath.row].valueForKey("title") as? String
        
        let URLString:NSURL = NSURL(string: courses[indexPath.row].valueForKey("piclink") as! String)!
        (cell as! MainTableViewCell).imgThumbnail.sd_setImageWithURL(URLString, placeholderImage: UIImage(named: "placeholder.png"))
        
        (cell as! MainTableViewCell).lblSource.text = courses[indexPath.row].valueForKey("school") as? String
        (cell as! MainTableViewCell).lblDuration.text = courses[indexPath.row].valueForKey("duration") as? String
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("You selected cell #\(indexPath.row)!")
        
        selectedCourseId = courses[indexPath.row].valueForKey("item_id") as? Int
        selectedTitle = courses[indexPath.row].valueForKey("title") as? String
        selectedDescription = courses[indexPath.row].valueForKey("description") as? String
        selectedVideoUrl = courses[indexPath.row].valueForKey("courselink") as? String
        selectedLink = courses[indexPath.row].valueForKey("link") as? String
        
        //Send request to server
        sendSelectedCourse(selectedCourseId)
        
        //if((selectedLink?.containsString("yixi")) == true){
        //    parseYixiCourse(selectedLink!);
        //}
        
        if(selectedVideoUrl == "" || selectedVideoUrl == nil){
            //Pass values
            showWebDetail()
        }
        else{
            showDetail()
        }
    }
    
    func sendSelectedCourse(courseId: Int){
        var courseSelected = [String: AnyObject]()
        courseSelected["user_id"] = User.sharedManager.userid
        courseSelected["item_id"] = courseId
        courseSelected["pref"] = 3
        
        let url = "http://jieko.cc/user/" + String(User.sharedManager.userid!) + "/Preferences"
        let request = NSMutableURLRequest(URL: NSURL(string: url)!)
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do{
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(courseSelected, options: [])
            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { data, response, error in
                guard error == nil && data != nil else {
                    print("error=\(error)")
                    return
                }
                
                if let httpStatus = response as? NSHTTPURLResponse where httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(response)")
                }
                
                let responseString = NSString(data: data!, encoding: NSUTF8StringEncoding)
                print("responseString = \(responseString)")
            }
            task.resume()
        } catch _{
            print("Error json")
        }
    }
    
    func showWebDetail() {
        let viewController = WebViewController(nibName: nil, bundle: nil)
        viewController.courseId = selectedCourseId
        viewController.courseTitle = selectedTitle
        viewController.courseDescription = selectedDescription
        viewController.courseLink = selectedLink
        let navigationController = UINavigationController(rootViewController: viewController)
        self.presentViewController(navigationController, animated: true, completion: nil)
        
    }
    
    func showDetail() {
        let viewController = DetailViewController(nibName: nil, bundle: nil)
        viewController.courseId = selectedCourseId
        viewController.courseTitle = selectedTitle
        viewController.courseDescription = selectedDescription
        viewController.courseVideoUrl = selectedVideoUrl
        viewController.courseLink = selectedLink
        self.presentViewController(viewController, animated: true, completion: nil)
    }

}

