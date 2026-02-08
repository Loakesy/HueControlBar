import UIKit
import HueColors


public protocol HueControlBarDelegate: AnyObject {
    func hueControlBarDidSelectOff(_ bar: HueControlBar)
    func hueControlBar(_ bar: HueControlBar, didSelectPredefinedColorAt index: Int, brightness: Int)
    func hueControlBar(_ bar: HueControlBar, didPick color: UIColor, xy: (x: Double, y: Double), brightness: Int)
    func hueControlBarDidSelectRandom(_ bar: HueControlBar, brightness: Int)
    func hueControlBarBrightnessChanged(_ bar: HueControlBar, brightness: Int)
    func hueControlBarSelectionDidExpire(_ bar: HueControlBar)
}

public final class HueControlBar: UIView {

    // MARK: - Configuration Properties

    public var buttonHeight: CGFloat = 28
    public var timerDelayButtons: TimeInterval = 15

    // MARK: - UI Elements

    private let islandColorView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 5
        v.clipsToBounds = true
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.12, alpha: 1)
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let contentView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 8
        sv.distribution = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private var colorButtons: [UIButton] = []
    private let offButton: UIButton = UIButton(type: .system)
    private let randomButton: UIButton = UIButton(type: .system)
    private let colorPickerButton: UIButton = UIButton(type: .system)
    private let brightnessSlider: UISlider = UISlider(frame: .zero)

    // MARK: - State

    private(set) var activeColorIndex: Int? = nil
    private(set) var pickedColorUI: UIColor? = nil
    private(set) var pickedColorXY: (x: Double, y: Double)? = nil
    private(set) var randomSelected: Bool = false
    private var selectionTimer: Timer?
    private var brightnessSelected: Int = 100

    // MARK: - Delegate

    public weak var delegate: HueControlBarDelegate?

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Public Methods

    public func resetSelection() {
        clearHighlights()
    }

    public func setBrightness(_ brightness: Int) {
        let clipped = max(0, min(100, brightness))
        brightnessSelected = clipped
        brightnessSlider.value = Float(clipped)
        delegate?.hueControlBarBrightnessChanged(self, brightness: clipped)
    }

    // MARK: - Private Setup

    private func setupUI() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        // Island color view (small indicator above the bar)
        addSubview(islandColorView)
        NSLayoutConstraint.activate([
            islandColorView.topAnchor.constraint(equalTo: topAnchor),
            islandColorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            islandColorView.widthAnchor.constraint(equalToConstant: 30),
            islandColorView.heightAnchor.constraint(equalToConstant: 10)
        ])

        // Container view with rounded corners
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: islandColorView.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 48)
        ])

        // Content stack view inside container
        containerView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            contentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            contentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            contentView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
        ])

        // Add Off button first
        offButton.setTitle("Off", for: .normal)
        offButton.setTitleColor(.white, for: .normal)
        offButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        offButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        offButton.layer.cornerRadius = buttonHeight/2
        offButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        offButton.translatesAutoresizingMaskIntoConstraints = false
        offButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        offButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        offButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        offButton.addTarget(self, action: #selector(offTapped(_:)), for: .touchUpInside)
        contentView.addArrangedSubview(offButton)

        // Add color buttons for predefined colors
        for (i, color) in HueColor.allColors.enumerated() {
            let btn = UIButton(type: .custom)
            btn.backgroundColor = color.uiColor
            btn.layer.cornerRadius = buttonHeight/2
            btn.layer.borderWidth = 2
            btn.layer.borderColor = UIColor.clear.cgColor
            btn.tag = i
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            btn.widthAnchor.constraint(equalToConstant: buttonHeight).isActive = true
            btn.setContentHuggingPriority(.defaultLow, for: .horizontal)
            btn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            btn.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            colorButtons.append(btn)
            contentView.addArrangedSubview(btn)
        }

        // Color picker button
        colorPickerButton.setTitle("\u{1F3A8}", for: .normal)
        colorPickerButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        colorPickerButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.layer.cornerRadius = buttonHeight/2
        colorPickerButton.translatesAutoresizingMaskIntoConstraints = false
        colorPickerButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        colorPickerButton.widthAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        colorPickerButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        colorPickerButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        colorPickerButton.addTarget(self, action: #selector(showColorPicker), for: .touchUpInside)
        contentView.addArrangedSubview(colorPickerButton)

        // Random button
        randomButton.setTitle("\u{1F3B2}", for: .normal)
        randomButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        randomButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        randomButton.layer.cornerRadius = buttonHeight/2
        randomButton.translatesAutoresizingMaskIntoConstraints = false
        randomButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        randomButton.widthAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        randomButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        randomButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        randomButton.addTarget(self, action: #selector(randomTapped), for: .touchUpInside)
        contentView.addArrangedSubview(randomButton)

        let equalWidthViews = [offButton] + colorButtons + [colorPickerButton, randomButton]
        for v in equalWidthViews {
            v.widthAnchor.constraint(equalTo: offButton.widthAnchor).isActive = true
        }

        // Brightness slider
        brightnessSlider.minimumValue = 0
        brightnessSlider.maximumValue = 100
        brightnessSlider.value = 100
        brightnessSlider.tintColor = UIColor.white
        brightnessSlider.translatesAutoresizingMaskIntoConstraints = false
        brightnessSlider.addTarget(self, action: #selector(brightnessChanged(_:)), for: .valueChanged)
        contentView.addArrangedSubview(brightnessSlider)
        brightnessSlider.setContentHuggingPriority(.required, for: .horizontal)
        brightnessSlider.setContentCompressionResistancePriority(.required, for: .horizontal)
        brightnessSlider.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.2).isActive = true

        // Initial island color
        updateIslandColor(clear: true)
    }

    // MARK: - Timer & Selection

    private func restartSelectionTimer() {
        selectionTimer?.invalidate()
        selectionTimer = Timer.scheduledTimer(withTimeInterval: timerDelayButtons, repeats: false, block: { [weak self] _ in
            guard let self = self else { return }
            self.clearHighlights()
            self.delegate?.hueControlBarSelectionDidExpire(self)
        })
    }

    private func clearHighlights() {
        activeColorIndex = nil
        pickedColorUI = nil
        pickedColorXY = nil
        randomSelected = false

        for btn in colorButtons {
            btn.layer.borderColor = UIColor.clear.cgColor
        }
        offButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        randomButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.backgroundColor = UIColor(white: 0.25, alpha: 1)

        updateIslandColor(clear: true)
        selectionTimer?.invalidate()
        selectionTimer = nil
    }

    // MARK: - Actions

    @objc private func colorTapped(_ sender: UIButton) {
        clearHighlights()
        activeColorIndex = sender.tag
        randomSelected = false
        pickedColorUI = nil
        pickedColorXY = nil

        for btn in colorButtons {
            btn.layer.borderColor = btn == sender ? UIColor.white.cgColor : UIColor.clear.cgColor
        }
        offButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        randomButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.backgroundColor = UIColor(white: 0.25, alpha: 1)

        brightnessSelected = Int(brightnessSlider.value)
        updateIslandColor()
        restartSelectionTimer()
        delegate?.hueControlBar(self, didSelectPredefinedColorAt: sender.tag, brightness: brightnessSelected)
    }

    @objc private func offTapped(_ sender: UIButton) {
        clearHighlights()
        activeColorIndex = nil
        randomSelected = false
        pickedColorUI = nil
        pickedColorXY = nil

        offButton.backgroundColor = UIColor(white: 0.4, alpha: 1)
        for btn in colorButtons {
            btn.layer.borderColor = UIColor.clear.cgColor
        }
        randomButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.backgroundColor = UIColor(white: 0.25, alpha: 1)

        updateIslandColor(clear: true)
        selectionTimer?.invalidate()
        selectionTimer = nil

        brightnessSelected = Int(brightnessSlider.value)
        delegate?.hueControlBarDidSelectOff(self)
    }

    @objc private func randomTapped() {
        clearHighlights()
        randomSelected = true
        activeColorIndex = nil
        pickedColorUI = nil
        pickedColorXY = nil

        randomButton.backgroundColor = UIColor(white: 0.4, alpha: 1)
        offButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        for btn in colorButtons {
            btn.layer.borderColor = UIColor.clear.cgColor
        }

        brightnessSelected = Int(brightnessSlider.value)
        updateIslandColor()
        restartSelectionTimer()
        delegate?.hueControlBarDidSelectRandom(self, brightness: brightnessSelected)
    }

    @objc private func brightnessChanged(_ sender: UISlider) {
        brightnessSelected = Int(sender.value)
        delegate?.hueControlBarBrightnessChanged(self, brightness: brightnessSelected)
    }

    @objc private func showColorPicker() {
        clearHighlights()
        offButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        randomButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.backgroundColor = UIColor(white: 0.4, alpha: 1)
        for btn in colorButtons {
            btn.layer.borderColor = UIColor.clear.cgColor
        }
        activeColorIndex = nil
        randomSelected = false

        guard let vc = nearestViewController() else { return }
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = pickedColorUI ?? .white
        picker.delegate = self
        vc.present(picker, animated: true)
    }

    // MARK: - Helper: Nearest UIViewController

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let vc = responder as? UIViewController {
                return vc
            }
            responder = responder?.next
        }
        return nil
    }

    // MARK: - Island Color Update (with random animation)

    private func updateIslandColor(clear: Bool = false) {
        selectionTimer?.invalidate()

        if clear {
            islandColorView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            islandColorView.backgroundColor = UIColor(white: 0.25, alpha: 1)
            return
        }

        if randomSelected {
            let gradient = CAGradientLayer()
            gradient.frame = islandColorView.bounds
            gradient.cornerRadius = islandColorView.layer.cornerRadius
            gradient.colors = HueColor.allColors.map { $0.uiColor.cgColor }
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)

            if islandColorView.layer.sublayers?.first is CAGradientLayer {
                islandColorView.layer.sublayers?.first?.removeFromSuperlayer()
            }
            islandColorView.layer.addSublayer(gradient)

            let animation = CABasicAnimation(keyPath: "colors")
            animation.duration = 6
            animation.toValue = HueColor.allColors.reversed().map { $0.uiColor.cgColor }
            animation.autoreverses = true
            animation.repeatCount = .infinity
            gradient.add(animation, forKey: "colorsAnimation")

            islandColorView.backgroundColor = .clear
        } else if let index = activeColorIndex, index < HueColor.allColors.count {
            islandColorView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            islandColorView.backgroundColor = HueColor.allColors[index].uiColor
        } else if let pickedColor = pickedColorUI {
            islandColorView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            islandColorView.backgroundColor = pickedColor
        } else {
            islandColorView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            islandColorView.backgroundColor = UIColor(white: 0.25, alpha: 1)
        }
    }

    // MARK: - Layout

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 58)
    }
}

// MARK: - UIColorPickerViewControllerDelegate

extension HueControlBar: UIColorPickerViewControllerDelegate {
    public func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        let selectedColor = viewController.selectedColor
        pickedColorUI = selectedColor
        activeColorIndex = nil
        randomSelected = false

        offButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        randomButton.backgroundColor = UIColor(white: 0.25, alpha: 1)
        colorPickerButton.backgroundColor = UIColor(white: 0.4, alpha: 1)
        for btn in colorButtons {
            btn.layer.borderColor = UIColor.clear.cgColor
        }

        updateIslandColor()
        restartSelectionTimer()

        guard let xy = CIEColor.xyFromUIColor(selectedColor) else {
            pickedColorXY = (0.3127, 0.3290)
            delegate?.hueControlBar(self, didPick: selectedColor, xy: (0.3127, 0.3290), brightness: brightnessSelected)
            return
        }
        pickedColorXY = xy
        delegate?.hueControlBar(self, didPick: selectedColor, xy: xy, brightness: brightnessSelected)

        viewController.dismiss(animated: true)
    }
}
