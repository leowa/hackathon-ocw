//
//  SearchViewController.swift
//  iosclient
//
//  Created by 典 杨 on 16/4/21.
//  Copyright © 2016年 典 杨. All rights reserved.
//

import UIKit
import TagListView
import Alamofire

class SearchViewController: UIViewController, UISearchBarDelegate, TagListViewDelegate {
    
    var searchBar: UISearchBar!
    
    @IBOutlet weak var tagListView: TagListView!
    
    var searchTags = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearchBar();
        searchTagsInit();
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setupSearchBar(){
        if let navigationBarFrame = navigationController?.navigationBar.bounds{
            let searchBar: UISearchBar = UISearchBar(frame: navigationBarFrame)
            searchBar.delegate = self
            searchBar.placeholder = "Search"
            //searchBar.showsCancelButton = true
            searchBar.autocapitalizationType = UITextAutocapitalizationType.None
            searchBar.keyboardType = UIKeyboardType.Default
            navigationItem.titleView = searchBar
            navigationItem.titleView?.frame = searchBar.frame
            self.searchBar = searchBar
            searchBar.becomeFirstResponder()
        }
    }
    
    func searchTagsInit(){
        tagListView.delegate = self
        tagListView.textFont = UIFont.systemFontOfSize(24)
        
        //Get tags from server
        
        Alamofire.request(.GET, "http://jieko.cc/user/" + String(User.sharedManager.userid!) + "/tags").responseJSON { response in
            let json = response.result.value!["tags"] as! NSArray
            
            for element in json{
                let ele = element as! NSArray
                self.tagListView.addTag(ele[0] as! String)
            }
        }
    }
    
    func tagPressed(title: String, tagView: TagView, sender: TagListView) {
        print("Tag pressed: \(title), \(sender)")
    }


}