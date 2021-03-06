//=============================================================================
// Copyright  2016 YI Technologies, Inc. All Rights Reserved.
//
// This software is the confidential and proprietary information of YI
// Technologies, Inc. ("Confidential Information").  You shall not
// disclose such Confidential Information and shall use it only in
// accordance with the terms of the license agreement you entered into
// with YI.
//
// YI MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE SUITABILITY OF THE
// SOFTWARE, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
// PURPOSE, OR NON-INFRINGEMENT. YI SHALL NOT BE LIABLE FOR ANY DAMAGES
// SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR DISTRIBUTING
// THIS SOFTWARE OR ITS DERIVATIVES.
//=============================================================================

import Foundation;
import YICameraSDK;

protocol CameraListener {
    func onStateChanged(camera: Camera, newState: Camera.State, oldState: Camera.State);
}

class Camera: ActionCameraListener
{
    enum State
    {
        case Disconnected;
        case Connecting;
        case Connected;
        case StartRecording;
        case Recording;
    }
    
    class DQ: DispatchQueue
    {
        @objc func dispatch(task task: () -> ()) {
            dispatch_async(dispatch_get_main_queue(), task);
        }
    }

    private var mState = State.Disconnected;
    private var mListener: CameraListener?;
    private var mIP = "";
    private var mHost = "";
    private var mYICamera: ActionCamera!;
    private var mTimer: NSTimer?;
    
    init(ip: String, host: String) {
        super.init();
        mIP = ip;
        mHost = host;
        mYICamera = ActionCamera(listener: self, dispatchQueue: DQ());
    }
    
    func setListener(listener: CameraListener?) {
        mListener = listener;
    }
    
    // Connect to YIActionCamera. Due to SDK doesn't support timeout in connect() currently,
    // we need handle timeout by our self.
    func connect() {
        setState(.Connecting);
        mTimer = NSTimer.scheduledTimerWithTimeInterval(5, target: self, selector: #selector(onConnectTimeout), userInfo: nil, repeats: false);
        mYICamera.connect(connectionString: "tcp:\(mIP):7878");
    }
    
    func startRecording(startTime: NSDate) {
        if (mState == .Connected) {
            setState(.StartRecording);
            mYICamera.stopRecording(success: nil, fail: nil)
                     .setSystemMode(mode: .Record, success: nil, fail: nil)
                     .setDateTime(
                        datetime: NSDate(),
                        success: {
                            self.mYICamera.startRecording(hour: startTime.getHours(), minute: startTime.getMinutes(), second: startTime.getSeconds(),
                                success: nil,
                                fail: { error in
                                    print("start recording failed: \(error.getCode())");
                                    if (self.mState == .StartRecording) {
                                        self.setState(.Connected);
                                    }
                            });
                        },
                        fail: { error in
                            print("set datetime failed: \(error.getCode())");
                            if (self.mState == .StartRecording) {
                                self.setState(.Connected);
                            }
                     });
        }
    }
    
    func stopRecording() {
        if (mState == .StartRecording || mState == .Recording) {
            mYICamera.stopRecording(success: nil, fail: nil);
        }
    }
    
    func getStatus() -> State {
        return mState;
    }
    
    func getIP() -> String {
        return mIP;
    }
    
    func getHost() -> String {
        return mHost;
    }
    
    override func onConnected() {
        print("connect to camera: \(mIP)");
        mTimer?.invalidate();
        setState(.Connected);
        mYICamera.getStatus(
            success: { status in
                if (status == .Recording) {
                    self.setState(.Recording);
                }
            },
            fail: nil);
    }
    
    override func onRecordStarted() {
        print("record started");
        setState(.Recording);
    }
    
    override func onRecordStopped() {
        print("record stoped");
        setState(.Connected);
    }
    
    override func onClosed(error error: Error?) {
        print("disconnect from camera: \(mIP)");
        setState(.Disconnected);
    }
    
    @objc private func onConnectTimeout() {
        print("connect timeout");
        mYICamera.disconnect();
    }
    
    private func setState(state: State) {
        if (mState != state) {
            let oldState = mState;
            mState = state;
            mListener?.onStateChanged(self, newState: mState, oldState: oldState);
        }
    }
}