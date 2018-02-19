//
//  AddPinViewController.swift
//  MTG
//
//  Created by Emerald on 17/2/18.
//  Copyright © 2018 Emerald. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Alamofire
import AlamofireImage

class AddPinViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    var locationManager = CLLocationManager()
    let authorizationStatus = CLLocationManager.authorizationStatus()
    let regionRadius: Double = 1000
    
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var bottomViewHeightConstraint: NSLayoutConstraint!
    
    var spinner: UIActivityIndicatorView?
    var progressLbl : UILabel?
    var screenSize =  UIScreen.main.bounds
    
    
    var flowLayout = UICollectionViewFlowLayout()
    var collectionView : UICollectionView?
    
    var imageURLArray = [String]()
    var imageArray = [UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        configureLocationServices()
        addDoubleTap()
        
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView?.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: "photoCell")
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = #colorLiteral(red: 0.9999960065, green: 1, blue: 1, alpha: 1)
        bottomView.addSubview(collectionView!)
        
        //3D touch
        registerForPreviewing(with: self, sourceView: collectionView!)
    }

    @IBAction func centerMapBtnPressed(_ sender: UIButton) {
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse{
            centerMapOnUserLocation()
        }
    }
    
    func addDoubleTap(){
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(dropPin(sender:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        mapView.addGestureRecognizer(doubleTap)
    }
    
    func animateViewUp(){
        bottomViewHeightConstraint.constant = 300
        UIView.animate(withDuration: 0.3) {
             self.view.layoutIfNeeded()
        }
       
    }
    func addSwipe(){
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(animateViewDown))
        swipe.direction = .down
        bottomView.addGestureRecognizer(swipe)
    }

    @objc func animateViewDown(){
        cancelAllSessions()
        bottomViewHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func addSpinner(){
        spinner = UIActivityIndicatorView()
        spinner?.center = CGPoint(x: (screenSize.width/2) - ((spinner?.frame.width)!/2), y: 150)
        spinner?.activityIndicatorViewStyle = .whiteLarge
        spinner?.color = #colorLiteral(red: 0.2605174184, green: 0.2605243921, blue: 0.260520637, alpha: 1)
        spinner?.startAnimating()
        collectionView?.addSubview(spinner!)
    }
    
    func removeSpinner(){
        if spinner != nil{
            spinner?.removeFromSuperview()
        }
    }
    
    func addProgressLbl(){
        progressLbl = UILabel()
        progressLbl?.frame = CGRect(x: (screenSize.width/2)-100 , y: 180, width: 250, height: 40)
        progressLbl?.font = UIFont(name: "Acenir Next", size: 14)
        progressLbl?.textAlignment = .center
        progressLbl?.textColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        collectionView?.addSubview(progressLbl!)
    }
    
    func removeProgressLbl(){
        if progressLbl != nil{
            progressLbl?.removeFromSuperview()
        }
    }
}


extension AddPinViewController: MKMapViewDelegate{
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation{
            return nil
        }
        
        let pinAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "droppablePin")
        pinAnnotation.tintColor = #colorLiteral(red: 0.9771530032, green: 0.7062081099, blue: 0.1748393774, alpha: 1)
        pinAnnotation.animatesDrop = true
        return pinAnnotation
    }
    
    func centerMapOnUserLocation(){
        guard let coordinate = locationManager.location?.coordinate else { return}
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, regionRadius * 2.0 , regionRadius * 2.0)
        
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    @objc func dropPin(sender: UITapGestureRecognizer){
        //remove old pin -> spinner, lbl, session, images first
        removePin()
        removeSpinner()
        removeProgressLbl()
        cancelAllSessions()
        
        imageArray = []
        self.collectionView?.reloadData()
        
        //Animate View Up
        animateViewUp()
        
        //**create touch point
        let touchPoint = sender.location(in: mapView) //print coordinate
        let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        let annotation = DroppablePin(coordinate: touchCoordinate, identifier: "droppablePin")
        mapView.addAnnotation(annotation)
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(touchCoordinate, regionRadius * 2.0 , regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        
        //add swipe down when pin down
        addSwipe()
        addSpinner()
        addProgressLbl()
        
        retrieveURLsforAnnotation(forAnnotation: annotation) { (finished) in
            if finished {
                self.retrieveImages(handler: { (fisished) in
                    if finished{
                        //hide spinner and lbl
                        self.removeSpinner()
                        self.removeProgressLbl()
                        //***reload collection view
                        self.collectionView?.reloadData()
                    }
                })
            }
        }
    }
    
    func removePin(){
        mapView.removeAnnotations(mapView.annotations)
//        for annotation in mapView.annotations{
//            mapView.removeAnnotation(annotation)
//        }
    }
    
    func retrieveURLsforAnnotation(forAnnotation annotation: DroppablePin, handler: @escaping (_ status: Bool) -> ()){
        imageURLArray = []
        
        Alamofire.request(flickrURL(forApiKey: apiKey, withAnnotation: annotation, andNumberOfPhotos: 20)).responseJSON { (response) in
            
            guard let json = response.result.value as? Dictionary<String, AnyObject> else {return}
            let photosDict = json["photos"] as? Dictionary<String, AnyObject>
            let photosDictArray = photosDict!["photo"] as? [Dictionary<String, AnyObject>]
            for photo in photosDictArray! {
                let postURL = "https://farm\(photo["farm"]!).staticflickr.com/\(photo["server"]!)/\(photo["id"]!)_\(photo["secret"]!)_h_d.jpg"
                self.imageURLArray.append(postURL)
            }
            handler(true)
        }
        
    }
    
    func retrieveImages(handler: @escaping(_ status: Bool)->()){
        imageArray = []
        for url in imageURLArray{
            Alamofire.request(url).responseImage(completionHandler: { (response) in
                guard let image = response.result.value else{return}
                self.imageArray.append(image)
                self.progressLbl?.text = "\(self.imageArray.count)/20 IMAGES LOADED"
                
                if self.imageArray.count == self.imageURLArray.count{
                    handler(true)
                }
            })
        }
    }
    
    func cancelAllSessions(){
        Alamofire.SessionManager.default.session.getTasksWithCompletionHandler { (sessionDataTask, uploadData, downloadData) in
            sessionDataTask.forEach({$0.cancel()})
            downloadData.forEach({$0.cancel()})
        }
    }
}

extension AddPinViewController: CLLocationManagerDelegate{
    
    func configureLocationServices(){
        if authorizationStatus == .notDetermined{
            locationManager.requestAlwaysAuthorization()
        }else{
            return
        }
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization: CLAuthorizationStatus){
        centerMapOnUserLocation()
    }
}

extension AddPinViewController:UICollectionViewDelegate, UICollectionViewDataSource{
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell  = collectionView.dequeueReusableCell(withReuseIdentifier: "photoCell", for: indexPath) as? PhotoCollectionViewCell else {return UICollectionViewCell()}
        let imageFromIndex = imageArray[indexPath.row]
        let imageView = UIImageView(image: imageFromIndex)

        imageView.contentMode = .scaleAspectFit
        
        cell.addSubview(imageView)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let popVC = storyboard?.instantiateViewController(withIdentifier: "PopVC") as? PopViewController else {return}
        popVC.initData(forImage: imageArray[indexPath.row])
        present(popVC, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize(width: 300, height: 300)
    }
}

extension AddPinViewController: UIViewControllerPreviewingDelegate{
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = collectionView?.indexPathForItem(at: location), let cell = collectionView?.cellForItem(at: indexPath) else {return nil}

        guard let popVC = storyboard?.instantiateViewController(withIdentifier: "PopVC") as? PopViewController else{return nil}
        
        popVC.initData(forImage: imageArray[indexPath.row])
        previewingContext.sourceRect = cell.contentView.frame
        return popVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        show(viewControllerToCommit, sender: self)
    }
    
    
}
