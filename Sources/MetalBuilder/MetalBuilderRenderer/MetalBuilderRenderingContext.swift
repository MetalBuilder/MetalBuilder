import MetalKit

/// Class that is passed to the MetalContent closure and contain useful values and methods.
/// Use the values in CPU code or pass them into shaders.
public final class MetalBuilderRenderingContext{
    /// Viewport size that can be used in a shader.
    @MetalState(metalName: "viewportSize") public var viewportSize: simd_uint2 = [0,0]
    /// Scale factor of the view. Used to convert point coordinates into pixel coordinates.
    @MetalState(metalName: "scaleFactor") public var scaleFactor: Float = 1
    /// Render time. Starts at zero and pauses when the app is in a background phase.
    ///
    /// You can manually pause and start the timer using `pauseTime` and `resumeTime` methods.
    @MetalState(metalName: "time") public var time: Float = 0
    /// Transformation matrix for transforming viewport coordinates into device coordinates.
    ///
    /// Use this matrix in a vertex shader to get device coordinates of your vertices:
    /// ```
    /// float2 yourVertexCoords = yourVertexBuffer[vertex_id];
    /// float3 pos = float3(yourVertexCoords, 1);
    /// pos *= viewportToDeviceTransform;
    /// VertexOut out;
    /// out.position = float4(pos.xy, 0, 1);
    /// return out;
    /// ```
    @MetalState(metalName: "viewportToDeviceTransform") public var viewportToDeviceTransform = simd_float3x3()
    
    @MetalState public var firstFrame = true
    
    public let device: MTLDevice
    
    let commandQueue: MTLCommandQueue
    
    init(commandQueue: MTLCommandQueue){
        self.commandQueue = commandQueue
        self.device = commandQueue.device
    }
    
    func updateViewportToDeviceTransform(){
        viewportToDeviceTransform = .init(columns: (
            [scaleFactor*2/Float(viewportSize.x), 0, -1],
            [0, -scaleFactor*2/Float(viewportSize.y), 1],
            [1,  1,  1]
        ))
    }
    
    func setViewportSize(_ size: CGSize){
        viewportSize = simd_uint2([UInt32(size.width), UInt32(size.height)])
        updateViewportToDeviceTransform()
    }
    func setScaleFactor(_ sf: CGFloat){
        scaleFactor = Float(sf)
        updateViewportToDeviceTransform()
    }
    
    weak var timer: MetalBuilderTimer?
    
    /// Pauses the timer.
    public func pauseTime(){
        timer?.manualPause()
    }
    /// Resumes the timer.
    public func resumeTime(){
        timer?.manualResume()
    }
}
